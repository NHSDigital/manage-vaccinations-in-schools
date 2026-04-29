# frozen_string_literal: true

class AddPatientIdIndexesToImportJoinTables < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = {
    class_imports_patients: %i[patient_id class_import_id],
    cohort_imports_patients: %i[patient_id cohort_import_id],
    immunisation_imports_patients: %i[patient_id immunisation_import_id]
  }.freeze

  def change
    INDEXES.each do |table_name, columns|
      add_index table_name, columns, unique: true, algorithm: :concurrently
    end
  end
end
