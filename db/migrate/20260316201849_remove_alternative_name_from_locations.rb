# frozen_string_literal: true

class RemoveAlternativeNameFromLocations < ActiveRecord::Migration[8.1]
  def change
    remove_column :locations, :alternative_name, :string
  end
end
