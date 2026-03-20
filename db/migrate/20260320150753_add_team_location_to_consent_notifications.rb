# frozen_string_literal: true

class AddTeamLocationToConsentNotifications < ActiveRecord::Migration[8.1]
  def change
    change_table :consent_notifications, bulk: true do |t|
      t.references :team_location
      t.change_null :session_id, true
    end
  end
end
