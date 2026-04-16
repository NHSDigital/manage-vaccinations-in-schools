# frozen_string_literal: true

class CSVParser
  def initialize(data)
    @data = data
  end

  def call
    CSV.parse(
      data,
      converters:,
      empty_value: nil,
      encoding:,
      header_converters:,
      headers: true,
      skip_blanks: true,
      strip: true
    )
  end

  def self.call(...) = new(...).call

  private_class_method :new

  Field =
    Struct.new("Field", :value, :column, :row, :header) do
      delegate :blank?, :present?, to: :value

      alias_method :to_s, :value

      def cell = "#{column}#{row}"

      def to_i
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      def to_date
        return nil if blank?

        parsed_values =
          DATE_FORMATS.lazy.filter_map do |format|
            date = Date.strptime(value, format)
            date.year >= 1000 ? date : nil
          rescue ArgumentError, TypeError
            nil
          end

        parsed_values.first
      end

      def to_postcode
        if present?
          postcode = UKPostcode.parse(value)
          postcode.to_s if PostcodeValidator.postcode_valid?(postcode)
        end
      end

      def to_time
        return nil if blank?

        parsed_values =
          TIME_FORMATS.lazy.filter_map do |format|
            # We change the date to 2000-01-01 as this is what Rails uses when
            #  it's reading from a `TIME` column.
            Time
              .zone
              .strptime(value, format)
              .change(year: 2000, month: 1, day: 1)
          rescue ArgumentError, TypeError
            nil
          end

        parsed_values.first
      end
    end

  private

  attr_reader :data

  ALPHABET = ("A".."Z").to_a.freeze
  COLUMNS = ALPHABET + ALPHABET.product(ALPHABET).map { _1 + _2 }

  DATE_FORMATS = %w[%Y%m%d %Y-%m-%d %d/%m/%Y].freeze
  TIME_FORMATS = %w[%H:%M:%S %H:%M %H%M%S %H%M %H].freeze

  def unconverted_headers
    @unconverted_headers ||=
      CSV.parse_line(data.lines.first, encoding:, strip: true)
  end

  def encoding
    "#{detect_encoding}:UTF-8" if detect_encoding
  end

  def detect_encoding
    @detect_encoding ||=
      begin
        return nil if data.blank?

        encoding = CharlockHolmes::EncodingDetector.detect(data)
        return nil if encoding.nil?

        encoding[:ruby_encoding]
      end
  end

  def converters
    proc do |value, info|
      column = COLUMNS[info.index]
      row = info.line
      header = unconverted_headers[info.index]

      Field.new(value&.normalise_whitespace, column, row, header)
    end
  end

  def header_converters
    proc do |value|
      value.downcase.normalise_whitespace.tr("-", "_").tr(" ", "_").to_sym
    end
  end
end
