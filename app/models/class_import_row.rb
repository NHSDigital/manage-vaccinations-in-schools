# frozen_string_literal: true

class ClassImportRow < PatientImportRow
  validate :validate_address_postcode

  def initialize(data:, team:, academic_year:, location:, year_groups:)
    super(data:, team:, academic_year:, year_groups:)
    @school = location
  end

  attr_reader :school

  def school_move_source = :class_list_import

  private

  def stage_registration?
    false
  end

  def validate_address_postcode
    if address_postcode.present? && address_postcode.to_postcode.nil?
      errors.add(address_postcode.header, "should be a postcode, like SW1A 1AA")
    end
  end
end
