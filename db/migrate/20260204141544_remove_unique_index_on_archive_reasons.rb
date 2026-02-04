# frozen_string_literal: true

class RemoveUniqueIndexOnArchiveReasons < ActiveRecord::Migration[7.0]
  def change
    remove_index :archive_reasons, %i[patient_id team_id]
    remove_index :archive_reasons, %i[team_id patient_id]
  end
end
