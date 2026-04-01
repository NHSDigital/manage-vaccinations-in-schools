# frozen_string_literal: true

class RemoveReportedAtFromVaccinationRecords < ActiveRecord::Migration[8.1]
  def change
    remove_column :vaccination_records, :reported_at, :datetime
  end
end
