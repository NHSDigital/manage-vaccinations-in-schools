# frozen_string_literal: true

class ChangeNotifyLogEntryPurposeToNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :notify_log_entries, :purpose, false
  end
end
