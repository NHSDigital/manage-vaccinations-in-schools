# frozen_string_literal: true

class AddContentToNotifyLogEntries < ActiveRecord::Migration[8.1]
  def change
    change_table :notify_log_entries, bulk: true do |t|
      t.text :subject
      t.text :body
    end
  end
end
