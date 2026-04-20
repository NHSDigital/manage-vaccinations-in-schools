# frozen_string_literal: true

module ImportsHelper
  def wait_for_import_to_complete(import_class)
    wait_for_import_to_complete_until_review(import_class)

    if page.has_button?("Approve and import records")
      click_on "Approve and import records"
    end

    wait_for_import_to_commit(import_class)
  end

  def wait_for_import_to_commit(import_class)
    CommitPatientChangesetsJob.drain
    click_on_most_recent_import(import_class)
  end

  def wait_for_import_to_complete_until_review(import_class)
    perform_enqueued_jobs(only: ProcessImportJob)

    if import_class != ImmunisationImport
      perform_enqueued_jobs_while_exists(only: PDSCascadingSearchJob)
      perform_enqueued_jobs_while_exists(only: ProcessPatientChangesetJob)
      perform_enqueued_jobs_while_exists(only: ReviewPatientChangesetJob)
      perform_enqueued_jobs(only: ReviewClassImportSchoolMoveJob)
    end

    click_on_most_recent_import(import_class)
  end

  def click_on_most_recent_import(import_class)
    link_text = import_class.order(:created_at).last.created_at.to_fs(:long)
    click_on link_text, match: :first if page.has_link?(link_text)
  end

  def perform_enqueued_jobs_while_exists(only:)
    job_class = only.name

    # rubocop:disable Style/WhileUntilModifier
    while enqueued_jobs.any? { it["job_class"] == job_class }
      perform_enqueued_jobs(only:)
    end
    # rubocop:enable Style/WhileUntilModifier
  end

  # Process and approve an import programmatically (for job/unit specs)
  # This simulates the full import flow including review and approval
  def process_and_approve_import(import)
    import.parse_rows!
    import.process!

    unless import.is_a?(ImmunisationImport)
      perform_enqueued_jobs_while_exists(only: PDSCascadingSearchJob)

      perform_enqueued_jobs_while_exists(only: ProcessPatientChangesetJob)
      perform_enqueued_jobs_while_exists(only: ReviewPatientChangesetJob)

      if import.is_a?(ClassImport)
        perform_enqueued_jobs_while_exists(only: ReviewClassImportSchoolMoveJob)
      end
    end

    # Use the same logic as approve actions in controllers
    import.committing!

    if import.is_a?(ClassImport)
      import.changesets.not_from_file.ready_for_review.update_all(
        status: :committing
      )
    end

    if import.changesets.from_file.ready_for_review.any?
      import.commit_changesets(import.changesets.from_file.ready_for_review)
    end

    CommitPatientChangesetsJob.drain
  end
end
