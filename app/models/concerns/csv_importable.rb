# frozen_string_literal: true

module CSVImportable
  extend ActiveSupport::Concern

  MAX_CSV_ROWS = 20_000

  included do
    attr_accessor :rows

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

    with_options on: :create do
      validate :csv_is_valid
      validate :csv_has_records, if: -> { csv_data_object.well_formed? }
      validate :csv_is_not_too_large, unless: -> { csv_data_object.empty? }
    end

    with_options on: :parse_rows do
      validate { rows.each(&:validate) }
      validates_with Import::RowsUniqueAcrossAllImmunisationAttributesValidator,
                     if: -> { is_a?(ImmunisationImport) }
      validates_with Import::RowsUniqueByNHSNumber,
                     if: -> { is_a?(PatientImport) }
      after_validation :aggregate_row_level_errors
    end

    before_save :ensure_processed_with_count_statistics
  end

  # Assign an uploaded CSV file to this import.
  #
  # Reads the uploaded file into {Import::CSVData}, stores the original filename,
  # and updates {#rows_count} based on the parsed CSV data.
  #
  # If the file contains a UTF byte-order mark (BOM) (common when exporting from
  # Excel), the encoding is detected and handled before reading.
  #
  # Raises an error if called on a persisted record, as changing the CSV file for
  # an existing import is not allowed.
  #
  # @param source [ActionDispatch::Http::UploadedFile] the uploaded CSV file
  # @raise [RuntimeError] if called on a persisted record
  # @raise [ArgumentError] if `source` is not an uploaded file
  def csv=(source)
    if persisted?
      raise "Cannot change the CSV file for an existing import. " \
              "Create a new import instead."
    end

    if source.is_a?(ActionDispatch::Http::UploadedFile)
      # CSV files exported from Excel may have a BOM.
      # https://en.wikipedia.org/wiki/Byte_order_mark
      # e.g. if you create a new class import from scratch in Excel on Mac v16,
      # save the file as CSV, and upload it.
      self.csv_data = source.to_io.tap(&:set_encoding_by_bom).read
      self.csv_filename = source&.original_filename
      self.rows_count = csv_data_object&.count
    else
      raise ArgumentError, "Expected an uploaded file, got #{source}"
    end
  end

  # Needed so that validations match the form field name.
  def csv = csv_data

  def csv_data_object
    @csv_data_object ||= Import::CSVData.new(csv_data)
  end

  def csv_removed?
    csv_removed_at != nil
  end

  def parse_rows!
    return if invalid?

    self.rows = csv_data_object.records.map { |row_data| parse_row(row_data) }

    if invalid?(:parse_rows)
      self.serialized_errors = errors.to_hash
      self.status = :rows_are_invalid
      save!(validate: false)
    end
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

  def count_columns
    %i[
      new_record_count
      changed_record_count
      exact_duplicate_record_count
    ].freeze
  end

  def ensure_processed_with_count_statistics
    if processed_at? && count_columns.any? { |column| send(column).nil? }
      raise "Count statistics must be set for a processed import."
    end
  end

  private

  def csv_is_valid
    errors.add(:csv, :invalid) unless csv_data_object.well_formed?
  end

  def csv_is_not_too_large
    if rows_count > MAX_CSV_ROWS
      errors.add(:csv, :too_many_rows, count: MAX_CSV_ROWS)
    end
  end

  def csv_has_records
    csv_has_no_records =
      csv_data_object.empty? ||
        (csv_data_object.count == 1 && csv_data_object.has_instruction_row?)
    errors.add(:csv, :empty) if csv_has_no_records
  end

  def aggregate_row_level_errors
    row_offset = csv_data_object.has_instruction_row? ? 3 : 2

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
end
