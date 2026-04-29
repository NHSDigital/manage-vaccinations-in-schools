# frozen_string_literal: true

class AddPhaseToLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :locations, :phase, :string
  end
end
