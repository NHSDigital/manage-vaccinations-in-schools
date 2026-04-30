# frozen_string_literal: true

class ReviewPatientChangesetJob < ApplicationJob
  sidekiq_options queue: :imports

  def perform(patient_changeset_id)
    patient_changeset =
      PatientChangeset.includes(patient: :school).find(patient_changeset_id)

    if patient_changeset.ready_for_review? || patient_changeset.import_invalid?
      return
    end

    patient_changeset.calculate_review_data!
    patient_changeset.assign_patient_id
    patient_changeset.ready_for_review!

    import = patient_changeset.import

    if all_jobs_finished_and_import_valid(import)
      if import.is_a?(ClassImport)
        ReviewClassImportSchoolMoveJob.perform_async(import.id)
      elsif import.calculating_re_review?
        import.in_re_review!
      else
        import.in_review!
      end
    end
  end

  private

  def all_jobs_finished_and_import_valid(import)
    import.changesets.still_processing.none? &&
      import.changesets.import_invalid.none?
  end
end
