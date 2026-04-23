# frozen_string_literal: true

class AddOpsSupportTeamAndEnableOpsTools < ActiveRecord::Migration[8.1]
  def up
    Flipper.enable(:ops_tools)

    return if Team.exists?(workgroup: CIS2Info::SUPPORT_WORKGROUP)

    Rake::Task['ops_support:seed'].execute
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
