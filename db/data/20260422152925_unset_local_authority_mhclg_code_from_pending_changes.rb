# frozen_string_literal: true

class UnsetLocalAuthorityMhclgCodeFromPendingChanges < ActiveRecord::Migration[8.1]
  def up
    count = Patient
      .where("pending_changes->>'address_postcode' IS NULL")
      .where("pending_changes->>'local_authority_mhclg_code' IS NOT NULL")
      .update_all <<~SQL
        local_authority_mhclg_code = pending_changes->>'local_authority_mhclg_code',
        pending_changes = pending_changes - 'local_authority_mhclg_code'
      SQL

    Rails.logger.debug "Updated #{count} patients"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
