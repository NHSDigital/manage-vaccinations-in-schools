# frozen_string_literal: true

class CohortImportRow < PatientImportRow
  validate :validate_address_postcode, :validate_school_urn

  def initialize(data:, team:, academic_year:)
    super(data:, team:, academic_year:, year_groups: team.year_groups)
  end

  def school_urn = @data[:child_school_urn]

  def school_move_source = :cohort_import

  def school
    @school ||=
      if (urn = school_urn&.to_s).present?
        schools.find_by_urn_and_site(urn) ||
          schools.find_by(systm_one_code: urn)
      end
  end

  private

  def schools
    Location
      .school
      .joins(:team_locations)
      .where(team_locations: { team:, academic_year: })
  end

  def stage_registration?
    true
  end

  def validate_address_postcode
    if address_postcode.nil?
      errors.add(:base, "<code>CHILD_POSTCODE</code> is required")
    elsif address_postcode.blank?
      errors.add(
        address_postcode.header,
        "Enter a valid postcode, like SW1A 1AA."
      )
    elsif address_postcode.to_postcode.nil?
      errors.add(address_postcode.header, "should be a postcode, like SW1A 1AA")
    end
  end

  def validate_school_urn
    if school_urn.nil?
      errors.add(:base, "<code>CHILD_SCHOOL_URN</code> is required")
    elsif school_urn.blank?
      errors.add(school_urn.header, "Enter a school URN.")
    elsif schools.where(urn: school_urn.to_s).where.not(site: nil).exists?
      errors.add(
        school_urn.header,
        "The URN #{school_urn} has been split into sites. " \
          "Use #{
            schools
              .where(urn: school_urn.to_s)
              .map(&:urn_and_site)
              .sort
              .to_sentence(
                two_words_connector: " or ",
                last_word_connector: " or "
              )
          } instead."
      )
    elsif !schools.where_urn_and_site(school_urn.to_s).exists? &&
          !schools.exists?(systm_one_code: school_urn.to_s)
      errors.add(
        school_urn.header,
        "The school URN is not recognised. If you’ve checked the URN, " \
          "and you believe it’s valid, contact our support team."
      )
    end
  end
end
