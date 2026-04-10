# frozen_string_literal: true

class AddDuplicateOfVaccinationRecordIdToVaccinationRecords < ActiveRecord::Migration[
  8.1
]
  def change
    add_reference :vaccination_records,
                  :duplicate_of_vaccination_record,
                  foreign_key: {
                    to_table: :vaccination_records
                  },
                  null: true
  end
end
