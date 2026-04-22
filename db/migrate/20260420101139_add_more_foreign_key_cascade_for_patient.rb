# frozen_string_literal: true

class AddMoreForeignKeyCascadeForPatient < ActiveRecord::Migration[8.1]
  TABLES_TO_CASCADE = %w[
    notify_log_entries
    school_move_log_entries
    patient_merge_log_entries
    pds_search_results
    patient_programme_vaccinations_searches
  ].freeze

  def change
    TABLES_TO_CASCADE.each do |table|
      remove_foreign_key table, "patients"
      add_foreign_key table, "patients", on_delete: :cascade, validate: false
    end

    remove_foreign_key "access_log_entries", "patients"
  end
end
