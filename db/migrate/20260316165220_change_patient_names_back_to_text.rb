# frozen_string_literal: true

class ChangePatientNamesBackToText < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Drop indexes on given_name/family_name concurrently first so the
    # ALTER COLUMN TYPE doesn't hold an ACCESS EXCLUSIVE lock while
    # rebuilding them.

    remove_index :patients,
                 column: %i[family_name given_name],
                 name: "index_patients_on_names_family_first",
                 algorithm: :concurrently
    remove_index :patients,
                 column: %i[given_name family_name],
                 name: "index_patients_on_names_given_first",
                 algorithm: :concurrently
    remove_index :patients,
                 column: :family_name,
                 name: "index_patients_on_family_name_trigram",
                 algorithm: :concurrently,
                 opclass: :gin_trgm_ops,
                 using: :gin
    remove_index :patients,
                 column: :given_name,
                 name: "index_patients_on_given_name_trigram",
                 algorithm: :concurrently,
                 opclass: :gin_trgm_ops,
                 using: :gin

    reversible do |dir|
      dir.up do
        change_table :patients, bulk: true do |t|
          t.change :given_name, :string, null: false
          t.change :family_name, :string, null: false
        end
      end
      dir.down do
        change_table :patients, bulk: true do |t|
          t.change :given_name, :citext, null: false
          t.change :family_name, :citext, null: false
        end
      end
    end

    add_index :patients,
              %i[family_name given_name],
              name: "index_patients_on_names_family_first",
              algorithm: :concurrently
    add_index :patients,
              %i[given_name family_name],
              name: "index_patients_on_names_given_first",
              algorithm: :concurrently
    add_index :patients,
              :family_name,
              name: "index_patients_on_family_name_trigram",
              opclass: :gin_trgm_ops,
              using: :gin,
              algorithm: :concurrently
    add_index :patients,
              :given_name,
              name: "index_patients_on_given_name_trigram",
              opclass: :gin_trgm_ops,
              using: :gin,
              algorithm: :concurrently
    disable_extension "citext"
  end
end
