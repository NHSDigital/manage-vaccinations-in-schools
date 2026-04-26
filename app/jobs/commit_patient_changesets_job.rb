# frozen_string_literal: true

class CommitPatientChangesetsJob
  include Sidekiq::Job
  include Sidekiq::Throttled::Job
  include PatientImportConcern

  queue_as :imports

  def perform(patient_changeset_ids)
    changesets =
      PatientChangeset.includes(:patient).where(id: patient_changeset_ids)
    import = changesets.first.import

    counts =
      import.count_columns.index_with { |col| import.public_send(col) || 0 }

    ActiveRecord::Base.transaction do
      # Reset patient_ids to avoid stale associations
      changesets.update_all(patient_id: nil)

      to_skip, to_process =
        changesets
          .select { review_consistent?(it) }
          .partition(&:skipped_school_move?)

      if to_process.any?
        increment_column_counts!(import, counts, to_process)
        import_patients_and_parents(to_process, import)
        import_school_moves(to_process, import)
        import_pds_search_results(to_process, import)
        to_process.each(&:processed!)
      end

      to_skip.each(&:processed!)

      PatientTeamUpdater.call(patient_scope: import.patients)
    end

    if finished_committing_changesets?(import)
      run_post_commit_tasks(import, counts)
    end

    import.post_commit!
  end

  private

  def review_consistent?(changeset)
    current_patient = changeset.patient
    current_school_move = changeset.school_move
    reviewed_data = changeset.review_data || {}

    current_pending_changes = current_patient.pending_changes
    reviewed_pending_changes =
      reviewed_data.dig("patient", "pending_changes") || {}
    if reviewed_pending_changes.key?("date_of_birth")
      reviewed_pending_changes["date_of_birth"] = reviewed_pending_changes[
        "date_of_birth"
      ].to_date
    end

    current_school_id =
      if current_school_move.present? &&
           !has_auto_confirmable_school_move?(
             current_school_move,
             changeset.import
           )
        current_school_move.school_id
      end
    reviewed_school_id = reviewed_data.dig("school_move", "school_id")

    current_record_type = changeset.changeset_type

    inconsistent =
      current_pending_changes != reviewed_pending_changes ||
        current_school_id != reviewed_school_id ||
        current_record_type.to_s != changeset.record_type.to_s

    changeset.needs_re_review! if inconsistent

    !inconsistent
  end

  def finished_committing_changesets?(import)
    import.changesets.from_file.committing.none?
  end

  # Tasks that get run after all the other batches have run
  def run_post_commit_tasks(import, counts)
    if import.changesets.needs_re_review.any?
      trigger_re_review(import)
    else
      import.update_columns(processed_at: Time.zone.now, status: :processed)
    end
    import.postprocess_rows!
    reset_counts(import)
    import.update_columns(**counts)
  end

  def trigger_re_review(import)
    import.calculating_re_review!
    import.changesets.needs_re_review.each do |changeset|
      changeset.calculating_review!
      ReviewPatientChangesetJob.perform_later(changeset.id)
    end
  end
end
