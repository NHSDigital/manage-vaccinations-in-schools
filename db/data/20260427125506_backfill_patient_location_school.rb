# frozen_string_literal: true

class BackfillPatientLocationSchool < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      UPDATE patient_locations
      SET school_id = location_id
      WHERE school_id IS NULL
    SQL
  end

  def down
    # Nothing to do to revert this.
  end
end
