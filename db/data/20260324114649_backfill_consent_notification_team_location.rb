# frozen_string_literal: true

class BackfillConsentNotificationTeamLocation < ActiveRecord::Migration[8.1]
  def up
    ConsentNotification
      .where(team_location_id: nil)
      .joins(:session)
      .update_all("team_location_id = sessions.team_location_id")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
