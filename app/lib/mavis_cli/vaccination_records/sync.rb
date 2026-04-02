# frozen_string_literal: true

module MavisCLI
  module VaccinationRecords
    class Sync < Dry::CLI::Command
      desc "Sync a vaccination record to NHS Immunisations API"
      argument :vaccination_record_id,
               required: true,
               desc: "ID of vaccination record to sync"

      def call(vaccination_record_id:, **)
        MavisCLI.load_rails

        unless Flipper.enabled?(:imms_api_integration)
          puts "Cannot sync vaccination record: the `imms_api_integration` feature flag is disabled"
          return
        end

        vaccination_record =
          ::VaccinationRecord.find_by(id: vaccination_record_id)

        if vaccination_record.nil?
          puts "Vaccination record with ID #{vaccination_record_id} not found"
          return
        end

        if vaccination_record.nhs_immunisations_api_synced_at.present?
          puts "Vaccination record #{vaccination_record_id} has already been" \
                 " synced at #{vaccination_record.nhs_immunisations_api_synced_at}"
          return
        end

        # Do not trigger the sync through the commit hook as we want to perform
        # the sync synchronously instead of enqueueing a background job.
        vaccination_record.update_columns(
          nhs_immunisations_api_sync_pending_at: Time.current,
          touch: true
        )
        NHS::ImmunisationsAPI.sync_immunisation(vaccination_record)
        puts "Successfully synced vaccination record #{vaccination_record_id}"
      end
    end
  end

  register "vaccination-records" do |prefix|
    prefix.register "sync", VaccinationRecords::Sync
  end
end
