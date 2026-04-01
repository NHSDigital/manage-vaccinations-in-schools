# frozen_string_literal: true

class AddFollowUpOutcomeToConsents < ActiveRecord::Migration[8.1]
  def change
    change_table :consents, bulk: true do |t|
      t.integer :follow_up_outcome
      t.datetime :follow_up_resolved_at
    end
  end
end
