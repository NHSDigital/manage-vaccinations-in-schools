# frozen_string_literal: true

class BulkRemoveVaccinationRecordsJob < ApplicationJob
  queue_as :imports

  def perform(import_id, vaccination_records_batch_ids)
    import = ImmunisationImport.find(import_id)
    return unless import

    patient_ids = []

    ActiveRecord::Base.transaction do
      vrs =
        import
          .vaccination_records
          .where(id: vaccination_records_batch_ids)
          .includes(:immunisation_imports)

      exclusive_vrs, shared_vrs =
        vrs.partition { |vr| vr.immunisation_imports.count == 1 }

      patient_ids = vrs.map(&:patient_id).uniq

      VaccinationRecord.where(id: exclusive_vrs.map(&:id)).destroy_all
      import.vaccination_records.delete(shared_vrs)

      Rails.logger.info(
        "Deleted #{exclusive_vrs.size} vaccination records and unlinked " \
          "#{shared_vrs.size} shared records from immunisation import #{import.id}"
      )
    end

    patient_scope = Patient.where(id: patient_ids)
    PatientTeamUpdater.call(patient_scope:)
    PatientStatusUpdater.call(patient_scope:)

    mark_complete_if_finished(import)
  end

  private

  def mark_complete_if_finished(import)
    return unless import.vaccination_records.empty?

    import.update!(status: :processed)
  end
end
