# frozen_string_literal: true

class AddSchoolToPatientLocations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :patient_locations,
                  :school,
                  foreign_key: {
                    to_table: :locations
                  }

    add_index :patient_locations,
              %i[school_id academic_year],
              algorithm: :concurrently

    add_index :patient_locations,
              %i[school_id academic_year patient_id],
              unique: true,
              algorithm: :concurrently

    add_index :patient_locations,
              %i[patient_id school_id academic_year],
              unique: true,
              algorithm: :concurrently
  end
end
