# frozen_string_literal: true

class RemoveLocationFromPatientLocations < ActiveRecord::Migration[8.1]
  def change
    remove_column :patient_locations, :location_id, :integer
  end
end
