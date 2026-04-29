# frozen_string_literal: true

class PatientImportRow
  include ActiveModel::Model

  MAX_FIELD_LENGTH = 300

  validate :validate_date_of_birth,
           :validate_existing_patients,
           :validate_first_name,
           :validate_preferred_first_name,
           :validate_gender_code,
           :validate_last_name,
           :validate_preferred_last_name,
           :validate_nhs_number,
           :validate_parent_1_email,
           :validate_parent_1_name,
           :validate_parent_1_phone,
           :validate_parent_1_relationship,
           :validate_parent_2_email,
           :validate_parent_2_name,
           :validate_parent_2_phone,
           :validate_parent_2_relationship,
           :validate_year_group

  def initialize(data:, team:, academic_year:, year_groups:)
    @data = data
    @team = team
    @academic_year = academic_year
    @year_groups = year_groups
  end

  def nhs_number = @data[:child_nhs_number]

  def first_name = @data[:child_first_name]

  def last_name = @data[:child_last_name]

  def preferred_first_name = @data[:child_preferred_first_name]

  def preferred_last_name = @data[:child_preferred_last_name]

  def date_of_birth = @data[:child_date_of_birth]

  def year_group = @data[:child_year_group]

  def registration = @data[:child_registration]

  def gender_code = @data[:child_gender]

  def address_line_1 = @data[:child_address_line_1]

  def address_line_2 = @data[:child_address_line_2]

  def address_town = @data[:child_town]

  def address_postcode = @data[:child_postcode]

  def parent_1_name = @data[:parent_1_name]

  def parent_1_relationship = @data[:parent_1_relationship]

  def parent_1_email = @data[:parent_1_email]

  def parent_1_phone = @data[:parent_1_phone]

  def parent_2_name = @data[:parent_2_name]

  def parent_2_relationship = @data[:parent_2_relationship]

  def parent_2_email = @data[:parent_2_email]

  def parent_2_phone = @data[:parent_2_phone]

  def nhs_number_value
    nhs_number&.to_s&.gsub(/\s/, "")
  end

  attr_reader :team, :academic_year, :year_groups

  def import_attributes
    @import_attributes ||= {
      # NOTE: The `&` protection for `.to_s` below may be superfluous, since
      #       we'd rather have "" here than `nil` so that the `.compact` below
      #       doesn't clear out the values, and we have less work later to
      #       ensure we don't leave values behind when we merge this in with the
      #       patient.
      address_line_1: address_line_1&.to_s,
      address_line_2: address_line_2&.to_s,
      address_postcode: address_postcode&.to_postcode,
      address_town: address_town&.to_s,
      local_authority_mhclg_code:
        LocalAuthority.for_postcode(address_postcode&.to_postcode)&.mhclg_code,
      birth_academic_year: birth_academic_year_value,
      date_of_birth: date_of_birth.to_date,
      family_name: ApostropheNormaliser.call(last_name.to_s),
      gender_code: gender_code_value,
      given_name: ApostropheNormaliser.call(first_name.to_s),
      nhs_number: nhs_number_value,
      preferred_family_name:
        ApostropheNormaliser.call(preferred_last_name&.to_s),
      preferred_given_name:
        ApostropheNormaliser.call(preferred_first_name&.to_s),
      registration: registration&.to_s,
      registration_academic_year:
    }.compact
  end

  def parent_1_import_attributes
    {
      full_name: parent_1_name_value,
      email: parent_1_email_value,
      phone: parent_1_phone_value,
      relationship: parent_1_relationship&.to_s
    }.compact
  end

  def parent_2_import_attributes
    {
      full_name: parent_2_name_value,
      email: parent_2_email_value,
      phone: parent_2_phone_value,
      relationship: parent_2_relationship&.to_s
    }.compact
  end

  private

  def parent_1_exists?
    [parent_1_name, parent_1_email, parent_1_phone].any?(&:present?)
  end

  def parent_2_exists?
    [parent_2_name, parent_2_email, parent_2_phone].any?(&:present?)
  end

  def parent_relationship_attributes(relationship)
    case relationship&.downcase
    when nil, "unknown"
      { type: "unknown" }
    when "mother", "mum"
      { type: "mother" }
    when "father", "dad"
      { type: "father" }
    when "guardian"
      { type: "guardian" }
    else
      { type: "other", other_name: relationship }
    end
  end

  def existing_patients
    if first_name.blank? || last_name.blank? || date_of_birth&.to_date.nil?
      return
    end

    PatientMatcher.from_relation(
      Patient.includes(:patient_locations),
      nhs_number: nhs_number_value,
      given_name: first_name.to_s,
      family_name: last_name.to_s,
      date_of_birth: date_of_birth.to_date,
      address_postcode: address_postcode&.to_postcode&.to_s
    )
  end

  def birth_academic_year_value
    if year_group.present?
      year_group&.to_i&.to_birth_academic_year(academic_year:)
    else
      date_of_birth&.to_date&.academic_year
    end
  end

  def gender_code_value
    gender_code&.to_s&.downcase&.gsub(" ", "_")
  end

  def parent_1_name_value
    ApostropheNormaliser.call(parent_1_name&.to_s)
  end

  def parent_1_email_value
    parent_1_email&.to_s&.downcase
  end

  def parent_2_name_value
    ApostropheNormaliser.call(parent_2_name&.to_s)
  end

  def parent_2_email_value
    parent_2_email&.to_s&.downcase
  end

  def parent_1_phone_value
    parent_1_phone&.to_s&.gsub(/\s/, "")
  end

  def parent_2_phone_value
    parent_2_phone&.to_s&.gsub(/\s/, "")
  end

  def registration_academic_year
    academic_year if registration.present?
  end

  def validate_date_of_birth
    if date_of_birth.nil?
      errors.add(:base, "<code>CHILD_DATE_OF_BIRTH</code> is required")
    elsif date_of_birth.blank?
      errors.add(date_of_birth.header, "Enter a date of birth.")
    elsif date_of_birth.to_date.nil?
      errors.add(date_of_birth.header, "should be formatted as YYYY-MM-DD")
    elsif date_of_birth.to_date < Date.new(2000, 1, 1)
      errors.add(date_of_birth.header, "is too old to still be in school")
    end
  end

  def validate_existing_patients
    if existing_patients&.length.to_i > 1
      errors.add(
        :base,
        "Two or more possible patients match the patient first name, last name, date of birth or postcode."
      )
    end
  end

  def validate_first_name
    if first_name.nil?
      errors.add(:base, "<code>CHILD_FIRST_NAME</code> is required")
    elsif first_name.blank?
      errors.add(first_name.header, "Enter a first name.")
    elsif first_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        first_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(attributes: [first_name.header]).validate_each(
        self,
        first_name.header,
        first_name.to_s
      )
    end
  end

  def validate_gender_code
    if gender_code.present? &&
         !Patient.gender_codes.keys.include?(gender_code_value)
      errors.add(gender_code.header, "is not a valid gender code")
    end
  end

  def validate_preferred_first_name
    return if preferred_first_name.blank?
    if preferred_first_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        preferred_first_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(
        attributes: [preferred_first_name.header]
      ).validate_each(
        self,
        preferred_first_name.header,
        preferred_first_name.to_s
      )
    end
  end

  def validate_last_name
    if last_name.nil?
      errors.add(:base, "<code>CHILD_LAST_NAME</code> is required")
    elsif last_name.blank?
      errors.add(last_name.header, "Enter a last name.")
    elsif last_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        last_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(attributes: [last_name.header]).validate_each(
        self,
        last_name.header,
        last_name.to_s
      )
    end
  end

  def validate_preferred_last_name
    return if preferred_last_name.blank?
    if preferred_last_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        preferred_last_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(attributes: [preferred_last_name.header]).validate_each(
        self,
        preferred_last_name.header,
        preferred_last_name.to_s
      )
    end
  end

  def validate_nhs_number
    return if nhs_number.blank?

    NHSNumberValidator.new(
      allow_blank: true,
      message: "should be a valid NHS number with 10 characters",
      attributes: [nhs_number.header]
    ).validate_each(self, nhs_number.header, nhs_number_value)
  end

  def validate_parent_1_name
    return if parent_1_name.blank?

    if parent_1_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        parent_1_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(attributes: [parent_1_name.header]).validate_each(
        self,
        parent_1_name.header,
        parent_1_name.to_s
      )
    end
  end

  def validate_parent_1_email
    return if parent_1_email.blank?

    NotifySafeEmailValidator.new(
      allow_blank: true,
      message: "should be a valid email address, like j.doe@example.com",
      attributes: [parent_1_email.header]
    ).validate_each(self, parent_1_email.header, parent_1_email_value)
  end

  def validate_parent_1_phone
    return if parent_1_phone.blank?

    PhoneValidator.new(
      allow_blank: true,
      message:
        "should be a valid phone number, like 01632 960 001, 07700 900 982 or +44 808 157 0192",
      attributes: [parent_1_phone.header]
    ).validate_each(self, parent_1_phone.header, parent_1_phone_value)
  end

  def validate_parent_1_relationship
    if parent_1_relationship.present? && !parent_1_exists?
      errors.add(parent_1_relationship.header, "must be blank")
    end
  end

  def validate_parent_2_name
    return if parent_2_name.blank?

    if parent_2_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        parent_2_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    else
      NameValidator.new(attributes: [parent_2_name.header]).validate_each(
        self,
        parent_2_name.header,
        parent_2_name.to_s
      )
    end
  end

  def validate_parent_2_email
    return if parent_2_email.blank?

    NotifySafeEmailValidator.new(
      allow_blank: true,
      message: "should be a valid email address, like j.doe@example.com",
      attributes: [parent_2_email.header]
    ).validate_each(self, parent_2_email.header, parent_2_email_value)
  end

  def validate_parent_2_phone
    return if parent_2_phone.blank?

    PhoneValidator.new(
      allow_blank: true,
      message:
        "should be a valid phone number, like 01632 960 001, 07700 900 982 or +44 808 157 0192",
      attributes: [parent_2_phone.header]
    ).validate_each(self, parent_2_phone.header, parent_2_phone_value)
  end

  def validate_parent_2_relationship
    if parent_2_relationship.present? && !parent_2_exists?
      errors.add(parent_2_relationship.header, "must be blank")
    end
  end

  def validate_year_group
    field = year_group.presence || date_of_birth

    year_group_value = birth_academic_year_value&.to_year_group(academic_year:)

    if year_group_value.nil?
      # We only need to add a validation error here is the file had an
      # explicit year group, since otherwise the year group comes from the
      # date of birth. If the date of birth is missing, there would already
      # be a validation error for that.

      if year_group.present?
        errors.add(field.header, "is not a valid year group")
      end

      return
    end

    unless year_group_value.in?(year_groups)
      errors.add(field.header, "is not part of this programme")
    end
  end
end
