# frozen_string_literal: true

class AddReverseIndexesToImportJoinTables < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = {
    class_imports_parent_relationships: %i[
      parent_relationship_id
      class_import_id
    ],
    cohort_imports_parent_relationships: %i[
      parent_relationship_id
      cohort_import_id
    ],
    immunisation_imports_vaccination_records: %i[
      vaccination_record_id
      immunisation_import_id
    ]
  }.freeze

  def change
    INDEXES.each do |table_name, columns|
      add_index table_name, columns, unique: true, algorithm: :concurrently
    end
  end
end
