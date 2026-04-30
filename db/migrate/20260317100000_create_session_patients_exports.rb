# frozen_string_literal: true

class CreateSessionPatientsExports < ActiveRecord::Migration[8.1]
  def change
    create_table :session_patients_exports do |t|
      t.references :session, null: false, foreign_key: true, index: false

      t.timestamps
    end
  end
end
