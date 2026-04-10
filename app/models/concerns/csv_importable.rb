# frozen_string_literal: true

module CSVImportable
  extend ActiveSupport::Concern

  MAX_CSV_ROWS = 20_000

  included do
    attr_accessor :csv_is_malformed, :data, :rows

    encrypts :csv_data

    belongs_to :team

    belongs_to :uploaded_by,
               class_name: "User",
               foreign_key: :uploaded_by_user_id

    has_and_belongs_to_many :patients

    scope :csv_not_removed, -> { where(csv_removed_at: nil) }
    scope :processed, -> { where.not(processed_at: nil) }

    scope :status_for_uploaded_files,
          -> do
            where(
              status: %i[
                pending_import
                rows_are_invalid
                low_pds_match_rate
                changesets_are_invalid
                in_review
                calculating_re_review
                in_re_review
                committing
                cancelled
              ]
            )
          end
    scope :status_for_imported_records,
          -> do
            where(
              status: %i[
                processed
                partially_processed
                removing_parent_relationships
              ]
            )
          end

    enum :status,
         {
           pending_import: 0,
           rows_are_invalid: 1,
           processed: 2,
           low_pds_match_rate: 3,
           changesets_are_invalid: 4,
           in_review: 5,
           calculating_re_review: 6,
           in_re_review: 7,
           committing: 8,
           partially_processed: 9,
           cancelled: 10,
           removing_parent_relationships: 11
         },
         default: :pending_import,
         validate: true

    validates :csv,
              absence: {
                if: :csv_removed?
              },
              presence: {
                unless: :csv_removed?
              }
    validates :csv_filename, presence: true

    validate :csv_is_valid
    validate :csv_has_records
    validate :csv_is_not_too_large
    validate :rows_are_valid

    before_save :ensure_processed_with_count_statistics
  end

  def csv=(file)
    self.csv_data = remove_bom_if_present(file&.read)
    self.csv_filename = file&.original_filename
  end

  # CSV files exported from Excel may have a BOM.
  # https://en.wikipedia.org/wiki/Byte_order_mark
  # e.g. if you create a new class import from scratch in Excel on Mac v16,
  # save the file as CSV, and upload it.
  def remove_bom_if_present(data)
    StringIO.new(data).tap(&:set_encoding_by_bom).read
  end

  # Needed so that validations match the form field name.
  def csv
    csv_data
  end

  def csv_removed?
    csv_removed_at != nil
  end

  def load_data!
    return if invalid?

    self.data ||= CSVParser.call(csv_data)
    self.rows_count = data.count
  rescue CSV::MalformedCSVError
    self.csv_is_malformed = true
  end

  def parse_rows!
    load_data! if data.nil?
    return if invalid?

    self.rows =
      remove_trailing_blank_rows(data)
        .then { |rows| has_instruction_row? ? rows.drop(1) : rows }
        .map { |row_data| parse_row(row_data) }

    if invalid?
      self.serialized_errors = errors.to_hash
      self.status = :rows_are_invalid
      save!(validate: false)
    end
  end

  def remove_trailing_blank_rows(table)
    found_values = false

    # map(&:itself) because CSV::Table doesn't have a reverse method
    rows_in_reverse_order = table.map(&:itself).reverse

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

  def has_instruction_row?
    data&.first&.[](0)&.to_s&.match?(/\A(Required|Optional)([,.:]|$)/)
  end

  def processed?
    processed_at != nil
  end

  def process!
    return if processed?

    parse_rows! if rows.nil?
    return if invalid?

    process_import!

    TeamCachedCounts.new(team).reset_import_issues!
  end

  def remove!
    return if csv_removed?
    update!(csv_data: nil, csv_removed_at: Time.zone.now)
  end

  def load_serialized_errors!(limit: nil)
    return if serialized_errors.blank?

    serialized_errors
      .then { limit ? it.first(limit) : it }
      .each do |attribute, messages|
        messages.each { errors.add(attribute, _1) }
      end
  end

  def csv_is_valid
    return unless csv_is_malformed

    errors.add(:csv, :invalid)
  end

  def csv_is_not_too_large
    return unless data

    if rows_count > MAX_CSV_ROWS
      errors.add(:csv, :too_many_rows, count: MAX_CSV_ROWS)
    end
  end

  def csv_has_records
    return unless data

    csv_has_no_records =
      data.empty? || (data.count == 1 && has_instruction_row?)
    errors.add(:csv, :empty) if csv_has_no_records
  end

  def rows_are_valid
    return unless rows

    rows.each(&:validate)

    check_rows_are_unique

    row_offset = has_instruction_row? ? 3 : 2

    rows.each.with_index do |row, index|
      next if row.errors.empty?

      # The first row is the header and the index is 0-based, so we add two
      # to match what the user sees in the spreadsheet

      formatted_errors =
        row.errors.map do |error|
          if error.attribute == :base
            error.message
          else
            "<code>#{error.attribute}</code>: #{error.message}"
          end
        end

      errors.add("row_#{index + row_offset}".to_sym, formatted_errors)
    end
  end

  def count_columns
    %i[
      new_record_count
      changed_record_count
      exact_duplicate_record_count
    ].freeze
  end

  def ensure_processed_with_count_statistics
    if processed? && count_columns.any? { |column| send(column).nil? }
      raise "Count statistics must be set for a processed import."
    end
  end

  def join_table_class(import_type, record_type)
    Class.new(ApplicationRecord) do
      @import_type = import_type.to_s.pluralize
      @record_type = record_type.to_s

      self.table_name = [@import_type, @record_type.pluralize].sort.join("_")

      def self.model_name
        ActiveModel::Name.new(
          self,
          nil,
          [@import_type.camelize, @record_type.singularize.camelize].sort.join
        )
      end
    end
  end

  def link_records_by_type(type, records)
    import_type = self.class.name.underscore
    type = type.to_s

    join_table_class(import_type, type).import(
      ["#{type.singularize}_id", "#{import_type}_id"],
      records.map(&:id).product([id]).uniq,
      on_duplicate_key_ignore: true
    )
  end
end
