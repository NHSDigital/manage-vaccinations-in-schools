# frozen_string_literal: true

class AddFollowUpRequestedToConsents < ActiveRecord::Migration[8.1]
  def change
    add_column :consents, :follow_up_requested, :boolean
  end
end
