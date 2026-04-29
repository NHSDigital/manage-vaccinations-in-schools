# frozen_string_literal: true

module Import
  class RowsUniqueAcrossAllImmunisationAttributesValidator < ActiveModel::Validator
    def validate(record)
      check_rows(record)
    end

    private

    def check_rows(record)
      row_offset = record.csv_data_object.has_instruction_row? ? 3 : 2

      record
        .rows
        .map(&:full_row_deduplication_attributes)
        .tally
        .each do |full_row_deduplication_attributes, count|
          next if count <= 1

          matching_rows =
            record.rows.each_with_index.select do |row, _index|
              row.full_row_deduplication_attributes ==
                full_row_deduplication_attributes
            end
          matching_rows = matching_rows.to_h

          matching_rows.each_key do |row|
            other_row_numbers =
              matching_rows
                .reject { |other_row, _| other_row.equal?(row) }
                .map { |_, other_index| other_index + row_offset }

            rows_text = "row".pluralize(other_row_numbers.size)
            other_row_numbers_text =
              other_row_numbers.to_sentence(last_word_connector: " and ")
            other_rows_text = "#{rows_text} #{other_row_numbers_text}"

            row.errors.add(
              :base,
              "The record on this row appears to be a duplicate of #{other_rows_text}."
            )
          end
        end
    end
  end
end
