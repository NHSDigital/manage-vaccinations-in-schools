# frozen_string_literal: true

class ProcessPatientChangesetJob < ApplicationJobActiveJob
  queue_as :imports

  def perform(patient_changeset_id)
    patient_changeset = PatientChangeset.find(patient_changeset_id)
    return if patient_changeset.processed_at?

    unique_nhs_number = get_unique_nhs_number(patient_changeset)
    if unique_nhs_number
      patient_changeset.child_attributes["nhs_number"] = unique_nhs_number
      patient_changeset.pds_nhs_number = unique_nhs_number
    end

    # we might now have an nhs number from pds lookup
    # validate whether there are multiple existing patients
    # if there are then fail the import, similar to how it fails if patient_import#validate_changeset_uniqueness! fails
    # set changeset#state to "duplicate_patients_found" or similar

    patient_changeset.assign_patient_id
    patient_changeset.calculating_review!

    if patient_changeset.import.changesets.pending.none?
      import = patient_changeset.import

      # if any of the changesets are in the "duplicate_patients_found" state then update the import:
      #   import.update!(status: :changesets_are_invalid)
      #   import.update!(serialized_errors: row_errors)
      #   changesets.update_all(status: :import_invalid)
      # end

      if Flipper.enabled?(:pds) && Flipper.enabled?(:pds_search_during_import)
        import.validate_pds_match_rate!
        return if import.low_pds_match_rate?
      end

      import.validate_changeset_uniqueness!
      return if import.changesets_are_invalid?
    end

    ReviewPatientChangesetJob.perform_later(patient_changeset.id)
  end

  private

  def get_unique_nhs_number(patient_changeset)
    nhs_numbers =
      patient_changeset.search_results.pluck("nhs_number").compact.uniq
    nhs_numbers.count == 1 ? nhs_numbers.first : nil
  end
end
