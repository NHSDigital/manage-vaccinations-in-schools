# frozen_string_literal: true

class AddUnarchivedDetailsToArchiveReason < ActiveRecord::Migration[8.1]
  def change
    add_column :archive_reasons, :unarchived_at, :datetime, null: true
    add_reference :archive_reasons,
                  :unarchived_by_user,
                  foreign_key: {
                    to_table: :users
                  }
    add_column :archive_reasons, :unarchive_reason, :integer
  end
end
