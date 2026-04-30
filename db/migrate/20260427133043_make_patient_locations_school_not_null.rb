# frozen_string_literal: true

class MakePatientLocationsSchoolNotNull < ActiveRecord::Migration[8.1]
  def change
    change_table :patient_locations, bulk: true do |t|
      t.change_null :school_id, false
      t.change_null :location_id, true
      t.remove_index %i[location_id academic_year]
      t.remove_index %i[location_id academic_year patient_id], unique: true
      t.remove_index %i[patient_id location_id academic_year], unique: true
      t.remove_foreign_key :locations
    end
  end
end
