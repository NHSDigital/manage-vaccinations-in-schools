# frozen_string_literal: true

class CreateVaccinationRecordsExports < ActiveRecord::Migration[8.1]
  def change
    create_table :vaccination_records_exports do |t|
      t.integer :academic_year, null: false
      t.date :date_from
      t.date :date_to
      t.string :file_format, null: false
      t.string :programme_type, null: false

      t.timestamps
    end
  end
end
