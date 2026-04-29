# frozen_string_literal: true

class SyncVaccinationRecordToNHSJob
  include Sidekiq::Job
  include ImmunisationsAPIThrottlingConcern

  sidekiq_options queue: :immunisations_api_sync,
                  lock: :until_and_while_executing

  def perform(vaccination_record_id)
    vaccination_record = VaccinationRecord.find(vaccination_record_id)

    unless Flipper.enabled?(:imms_api_sync_job, vaccination_record.programme)
      return
    end

    NHS::ImmunisationsAPI.sync_immunisation(vaccination_record)
  end
end
