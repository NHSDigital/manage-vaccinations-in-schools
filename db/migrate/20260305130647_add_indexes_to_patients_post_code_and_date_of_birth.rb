# frozen_string_literal: true

class AddIndexesToPatientsPostCodeAndDateOfBirth < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    change_table :patients, bulk: true do |t|
      t.index :address_postcode, algorithm: :concurrently
      t.index :date_of_birth, algorithm: :concurrently
    end
  end
end
