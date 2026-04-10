# frozen_string_literal: true

class RemoveHomeEducatedAndTeamFromSchoolMoves < ActiveRecord::Migration[8.1]
  def change
    change_table :school_moves, bulk: true do |t|
      t.remove :home_educated, type: :boolean
      t.remove_references :team
    end
  end
end
