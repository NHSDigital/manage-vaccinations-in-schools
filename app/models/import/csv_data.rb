# frozen_string_literal: true

class Import::CSVData
  attr_accessor :data, :malformed

  # Use with serialization in the Import model
  def initialize(data)
    @data = data
  end

  def well_formed?
    csv_table
    !malformed
  end

  def empty? = csv_table.blank?

  def csv_table
    @csv_table ||=
      begin
        CSVParser.call(data) if data.present?
      rescue CSV::MalformedCSVError
        @malformed = true
        nil
      end
  end

  def count = csv_table&.count || 0

  def records(&block)
    remove_trailing_blank_rows
      .then { |rows| has_instruction_row? ? rows.drop(1) : rows }
      .each(&block)
  end

  def has_instruction_row?
    csv_table&.first&.[](0)&.to_s&.match?(/\A(Required|Optional)([,.:]|$)/)
  end

  private

  def remove_trailing_blank_rows
    found_values = false

    # map(&:itself) because CSV::Table doesn't have a reverse method
    rows_in_reverse_order = csv_table.map(&:itself).reverse

    filtered_rows =
      rows_in_reverse_order.select do |row|
        if found_values
          true
        elsif row.fields.all?(&:blank?)
          false
        else
          found_values = true
          true
        end
      end

    filtered_rows.reverse
  end
end
