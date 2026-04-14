# frozen_string_literal: true

class AddNHSImmunisationsAPIRecordedAtToVaccinationRecords < ActiveRecord::Migration[
  8.1
]
  def change
    add_column :vaccination_records,
               :nhs_immunisations_api_recorded_at,
               :datetime
  end
end
