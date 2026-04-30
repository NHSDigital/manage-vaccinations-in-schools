# frozen_string_literal: true

class AddCancelledAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :cancelled_at, :datetime
  end
end
