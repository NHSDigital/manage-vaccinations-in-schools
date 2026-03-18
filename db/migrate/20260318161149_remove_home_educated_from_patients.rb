# frozen_string_literal: true

class RemoveHomeEducatedFromPatients < ActiveRecord::Migration[8.1]
  def change
    remove_column :patients, :home_educated, :boolean
  end
end
