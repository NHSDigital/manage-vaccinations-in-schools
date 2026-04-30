# frozen_string_literal: true

class CreateLocationPatientsExports < ActiveRecord::Migration[8.1]
  def change
    create_table :location_patients_exports do |t|
      t.integer :academic_year, null: false
      t.jsonb :filter_params, null: false, default: {}
      t.references :location, null: false, foreign_key: true, index: false

      t.timestamps
    end
  end
end
