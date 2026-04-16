# frozen_string_literal: true

class AddReasonCodeToVaccinationRecords < ActiveRecord::Migration[8.1]
  def change
    change_table :vaccination_records, bulk: true do |t|
      t.string :nhs_immunisations_api_snomed_reason_code
      t.string :nhs_immunisations_api_snomed_reason_term
    end
  end
end
