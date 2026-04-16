# frozen_string_literal: true

class AddPositionToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :position, :st_point, geographic: true
  end
end
