# frozen_string_literal: true

class ValidatePatientForeignKeys < ActiveRecord::Migration[8.1]
  TABLES_TO_CASCADE = %w[
    notify_log_entries
    school_move_log_entries
    patient_merge_log_entries
    pds_search_results
    patient_programme_vaccinations_searches
  ].freeze

  def change
    TABLES_TO_CASCADE.each { |table| validate_foreign_key table, "patients" }
  end
end
