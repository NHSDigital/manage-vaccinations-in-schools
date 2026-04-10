# frozen_string_literal: true

class MakeConsentNotificationTeamLocationNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :consent_notifications, :team_location_id, false
  end
end
