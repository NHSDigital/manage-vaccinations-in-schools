# frozen_string_literal: true

class DropInvitationColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :sessions, :send_invitations_at, :date
    remove_column :teams, :days_before_invitations, :integer
  end
end
