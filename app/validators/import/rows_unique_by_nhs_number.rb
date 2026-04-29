# frozen_string_literal: true

module Import
  class RowsUniqueByNHSNumber < ActiveModel::Validator
    def validate(record)
      check_rows(record)
    end

    private

    def check_rows(record)
      record
        .rows
        .map(&:nhs_number_value)
        .tally
        .each do |nhs_number, count|
          next if nhs_number.nil? || count <= 1

          record
            .rows
            .select { _1.nhs_number_value == nhs_number }
            .each do |row|
              row.errors.add(
                :base,
                "The same NHS number appears multiple times in this file."
              )
            end
        end
    end
  end
end
