# frozen_string_literal: true

class AddCareplusCredentialsToTeams < ActiveRecord::Migration[8.1]
  def change
    change_table :teams, bulk: true do |t|
      t.string :careplus_username
      t.string :careplus_password
    end
  end
end
