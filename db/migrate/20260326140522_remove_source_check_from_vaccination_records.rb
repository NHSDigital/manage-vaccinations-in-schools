# frozen_string_literal: true

class RemoveSourceCheckFromVaccinationRecords < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :vaccination_records,
                            "(session_id IS NULL AND source != 0 AND source != 5) OR " \
                              "(session_id IS NOT NULL AND (source = 0 OR source = 5))",
                            name: "source_check",
                            validate: false
  end
end
