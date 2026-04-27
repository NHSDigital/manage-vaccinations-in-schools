# frozen_string_literal: true

module Imports
  class BulkRemoveVaccinationRecordsController < ApplicationController
    BATCH_SIZE = 100

    before_action :set_import

    skip_after_action :verify_policy_scoped

    def new
      vaccination_records =
        @import.vaccination_records.joins(:immunisation_imports)

      @exclusive_count =
        vaccination_records
          .group("vaccination_records.id")
          .having("COUNT(immunisation_imports.id) = 1")
          .count
          .size

      @shared_count = @import.vaccination_records.count - @exclusive_count
    end

    def create
      @import.update!(status: :removing_vaccination_records)

      @import
        .vaccination_record_ids
        .each_slice(BATCH_SIZE) do |batch_ids|
          BulkRemoveVaccinationRecordsJob.perform_later(@import.id, batch_ids)
        end

      redirect_to records_imports_path, flash: { success: t(".success_flash") }
    end

    private

    def set_import
      @import = ImmunisationImport.find(params[:import_id])
      authorize @import,
                policy_class:
                  ImmunisationImport::BulkRemoveVaccinationRecordPolicy
    end
  end
end
