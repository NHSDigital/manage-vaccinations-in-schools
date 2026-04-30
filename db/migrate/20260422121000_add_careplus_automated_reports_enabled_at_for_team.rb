# frozen_string_literal: true

class AddCareplusAutomatedReportsEnabledAtForTeam < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :careplus_automated_reports_enabled_at, :datetime
  end
end
