# frozen_string_literal: true

class ChangeIndexOnLocationURN < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :locations,
                 :urn,
                 unique: true,
                 where: "site IS NULL",
                 algorithm: :concurrently

    add_index :locations,
              :urn,
              unique: true,
              where: "type = 0 AND site IS NULL",
              algorithm: :concurrently
  end
end
