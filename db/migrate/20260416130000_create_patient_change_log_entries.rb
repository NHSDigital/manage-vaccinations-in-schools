# frozen_string_literal: true

class CreatePatientChangeLogEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :patient_change_log_entries do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.integer :source, null: false
      t.jsonb :recorded_changes, null: false, default: {}
      t.timestamps
    end
  end
end
