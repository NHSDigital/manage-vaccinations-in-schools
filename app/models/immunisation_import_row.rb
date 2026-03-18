# frozen_string_literal: true

class ImmunisationImportRow
  include ActiveModel::Model

  include PerformableAtDateAndTime

  validate :validate_administered

  validate :validate_batch_expiry,
           :validate_batch_name,
           :validate_care_setting,
           :validate_clinic_name,
           :validate_date_of_vaccination,
           :validate_delivery_site,
           :validate_dose_sequence,
           :validate_existing_patients,
           :validate_local_patient_id,
           :validate_local_patient_id_uri,
           :validate_patient_date_of_birth,
           :validate_patient_first_name,
           :validate_patient_gender_code,
           :validate_patient_last_name,
           :validate_patient_nhs_number,
           :validate_patient_postcode,
           :validate_performed_by,
           :validate_performed_ods_code,
           :validate_programme,
           :validate_reason_not_administered,
           :validate_school_name,
           :validate_school_urn,
           :validate_supplied_by,
           :validate_session_id,
           :validate_time_of_vaccination,
           :validate_uuid,
           :validate_vaccine,
           unless: :national_reporting_not_administered?

  CARE_SETTING_SCHOOL = 1
  CARE_SETTING_COMMUNITY = 2

  SESSION_ID_CLINIC = "clinic"

  MAX_FIELD_LENGTH = 300

  DELIVERY_SITES = {
    "left thigh" => "left_thigh",
    "right thigh" => "right_thigh",
    "left upper arm" => "left_arm_upper_position",
    "left deltoid" => "left_arm_upper_position",
    "left arm (upper position)" => "left_arm_upper_position",
    "left arm (lower position)" => "left_arm_lower_position",
    "right upper arm" => "right_arm_upper_position",
    "right deltoid" => "right_arm_upper_position",
    "right arm (upper position)" => "right_arm_upper_position",
    "right arm (lower position)" => "right_arm_lower_position",
    "left buttock" => "left_buttock",
    "right buttock" => "right_buttock",
    "nasal" => "nose"
  }.freeze

  DOSE_SEQUENCES = {
    "hpv" => {
      "1P" => 1,
      "2P" => 2,
      "3P" => 3
    },
    "mmr" => {
      "1P" => 1,
      "1B" => 2
    },
    "menacwy" => {
      "1P" => 1,
      "1B" => 2,
      "2B" => 3,
      "1st Scheduled Booster" => 2,
      "2nd Scheduled Booster" => 3
    },
    "td_ipv" => {
      "1P" => 1,
      "2P" => 2,
      "3P" => 3,
      "1B" => 4,
      "2B" => 5,
      "1st Scheduled Booster" => 4,
      "2nd Scheduled Booster" => 5
    }
  }.freeze

  REASONS_NOT_ADMINISTERED = {
    "refused" => :refused,
    "unwell" => :unwell,
    "vaccination contraindicated" => :contraindicated,
    "already had elsewhere" => :already_had
  }.freeze

  attr_reader :team, :type, :patient

  def initialize(data:, team:, type:)
    @data = data
    @team = team
    @type = type&.to_sym
  end

  def point_of_care? = type == :point_of_care

  def national_reporting_flu? = national_reporting? && programme&.flu?

  def national_reporting_hpv? = national_reporting? && programme&.hpv?

  def national_reporting? = type == :national_reporting

  def national_reporting_not_administered?
    national_reporting? && !administered
  end

  def to_vaccination_record
    return if invalid? || national_reporting_not_administered? || patient.nil?

    vaccination_record =
      if uuid.present?
        VaccinationRecord
          .find_by!(uuid: uuid.to_s)
          .tap { it.stage_changes(attributes) }
      else
        VaccinationRecord.find_or_initialize_by(deduplication_attributes)
      end

    if vaccination_record.persisted?
      vaccination_record.stage_changes(attributes_to_stage_if_already_exists)
      should_stage_delivery_attributes =
        vaccination_record.pending_changes? ||
          (
            (
              vaccination_record.delivery_site.present? &&
                delivery_site_value.present?
            ) ||
              (
                vaccination_record.delivery_method.present? &&
                  delivery_method_value.present?
              )
          )
      if should_stage_delivery_attributes
        vaccination_record.stage_changes(delivery_attributes)
      else
        vaccination_record.assign_attributes(delivery_attributes.compact)
      end
    else
      # Postgres UUID generation is skipped in bulk import
      vaccination_record.uuid = SecureRandom.uuid

      vaccination_record.assign_attributes(
        attributes_to_stage_if_already_exists.merge!(delivery_attributes)
      )
    end

    vaccination_record
  end

  def to_patient_location
    if patient && session
      PatientLocation.new(patient:, location: session.location, academic_year:)
    end
  end

  def to_archive_reason
    # If the patient is new to this team, we need to add an archive reason for this team
    unless patient&.teams&.include?(team)
      ArchiveReason.new(patient:, team:, type: :immunisation_import)
    end
  end

  def set_patient(candidates: nil)
    # Invalidate the memoised `@attributes`, which might reference the old value of `@patient` (likely to be `nil`)
    @attributes = nil

    @patient =
      existing_patients(candidates:)&.first ||
        Patient.new(new_patient_attributes)
  end

  def attributes
    @attributes ||=
      begin
        outcome =
          (administered ? "administered" : reason_not_administered_value)

        attributes = {
          disease_types:,
          dose_sequence: dose_sequence_value,
          full_dose: true,
          outcome:,
          patient:,
          performed_at_date:,
          performed_by_user:,
          performed_ods_code: performed_ods_code&.to_s,
          programme_type: programme&.type,
          protocol:,
          session:,
          supplied_by:
        }

        attributes.merge!(location:, location_name:) unless imms_api_record?
        attributes.merge!(notify_parents: true) if session

        if performed_by_user.nil? &&
             (
               performed_by_family_name.present? ||
                 performed_by_given_name.present?
             )
          attributes.merge!(
            performed_by_family_name: performed_by_family_name&.to_s,
            performed_by_given_name: performed_by_given_name&.to_s
          )
        end

        if national_reporting?
          attributes.merge!(
            local_patient_id: local_patient_id&.to_s,
            local_patient_id_uri: local_patient_id_uri&.to_s
          )
        end

        attributes
      end
  end

  def attributes_to_stage_if_already_exists
    @attributes_to_stage_if_already_exists ||= {
      batch_number: batch_name&.to_s,
      batch_expiry: batch_expiry&.to_date,
      discarded_at: nil,
      notes: notes&.to_s,
      performed_at_time:,
      source:,
      vaccine_id: vaccine&.id
    }
  end

  def delivery_attributes
    @delivery_attributes ||= {
      delivery_method: delivery_method_value,
      delivery_site: delivery_site_value
    }
  end

  def deduplication_attributes
    if national_reporting?
      attributes.merge(
        attributes_to_stage_if_already_exists,
        delivery_attributes
      )
    else
      attributes
    end
  end

  def full_row_deduplication_attributes
    deduplication_attributes.merge(new_patient_attributes)
  end

  def batch_expiry = @data[:batch_expiry_date]

  def batch_name = @data[:batch_number] || @data[:vaccination_batch_number]

  def care_setting = point_of_care? ? @data[:care_setting] : nil

  def clinic_name =
    point_of_care? ? @data[:clinic_name] || @data[:event_done_at] : nil

  def combined_vaccination_and_dose_sequence =
    point_of_care? ? @data[:vaccination_type] : nil

  def date_of_vaccination = @data[:date_of_vaccination] || @data[:event_date]

  def delivery_site = @data[:anatomical_site]

  def dose_sequence = @data[:dose_sequence]

  def location_type = point_of_care? ? @data[:event_location_type] : nil

  def notes = point_of_care? ? @data[:notes] : nil

  def patient_date_of_birth = @data[:person_dob] || @data[:date_of_birth]

  def patient_first_name = @data[:person_forename] || @data[:first_name]

  def patient_gender_code =
    @data[:person_gender_code] || @data[:person_gender] || @data[:sex]

  def patient_last_name = @data[:person_surname] || @data[:surname]

  def patient_nhs_number = @data[:nhs_number]

  def patient_postcode = @data[:person_postcode] || @data[:postcode]

  def performed_by_email =
    point_of_care? ? @data[:performing_professional_email] : nil

  def performed_by_family_name = @data[:performing_professional_surname]

  def performed_by_given_name = @data[:performing_professional_forename]

  def performed_ods_code = @data[:organisation_code]

  def programme_name = point_of_care? ? @data[:programme] : nil

  def reason_not_administered =
    point_of_care? ? @data[:reason_not_vaccinated] : nil

  def school_name =
    if point_of_care?
      @data[:school_name] || @data[:school] || @data[:event_done_at]
    end

  def school_urn = @data[:school_urn] || @data[:school_code]

  def session_id = point_of_care? ? @data[:session_id] : nil

  def supplied_by_email = point_of_care? ? @data[:supplier_email] : nil

  def time_of_vaccination = @data[:time_of_vaccination] || @data[:event_time]

  def uuid = point_of_care? ? @data[:uuid] : nil

  def vaccinated = @data[:vaccinated]

  def vaccine_name = @data[:vaccine_given]

  def local_patient_id = national_reporting? ? @data[:local_patient_id] : nil

  def local_patient_id_uri =
    national_reporting? ? @data[:local_patient_id_uri] : nil

  private

  delegate :organisation, to: :team

  def location
    if national_reporting?
      school
    elsif !session&.generic_clinic?
      session&.location
    end
  end

  def location_name
    return unless location.nil?

    if is_school_setting? || (is_unknown_setting? && clinic_name.blank?)
      school&.school? ? school.name : school_name&.to_s || "Unknown"
    else
      clinic&.name || clinic_name&.to_s || "Unknown"
    end
  end

  def performed_at_date = date_of_vaccination&.to_date

  def performed_at_time = time_of_vaccination&.to_time

  def performed_by_user
    @performed_by_user ||=
      if (email = performed_by_email&.to_s)
        User.find_by(email:)
      end
  end

  def supplied_by
    @supplied_by ||=
      if (email = supplied_by_email&.to_s)
        User.find_by(email:)
      end
  end

  def school
    @school ||=
      if school_urn.to_s == Location::URN_HOME_EDUCATED
        team.home_educated_school
      elsif school_urn.to_s == Location::URN_UNKNOWN
        team.unknown_school
      elsif school_urn.present?
        Location.school.find_by_urn_and_site(school_urn.to_s) ||
          Location.school.find_by(systm_one_code: school_urn.to_s)
      end
  end

  def clinic
    @clinic ||=
      if clinic_name.present?
        team.community_clinics.find_by(
          "LOWER(locations.name) = ?",
          clinic_name.to_s.downcase
        )
      end
  end

  def programme
    @programme ||=
      begin
        name =
          parsed_vaccination_description_string&.dig(:programme_name) ||
            programme_name&.to_s

        programmes_by_name[name&.downcase] || vaccine&.programme
      end
  end

  def session
    @session ||=
      if session_id&.to_s == SESSION_ID_CLINIC && academic_year &&
           (programme_type = programme&.type) && performed_at_date.present?
        ClinicSessionFactory.call(
          team:,
          academic_year:,
          programme_type:,
          date: performed_at_date
        )
      elsif (id = session_id&.to_i)
        Session
          .joins(:team_location)
          .where(team_location: { team: })
          .includes(:location, :session_programme_year_groups)
          .find_by(id:)
      end
  end

  def source
    if imms_api_record?
      "nhs_immunisations_api"
    elsif offline_recording?
      "service"
    elsif point_of_care?
      "historical_upload"
    else
      "national_reporting"
    end
  end

  def protocol
    if imms_api_record?
      nil
    elsif supplied_by && supplied_by != performed_by_user
      if patient
           .patient_specific_directions
           .for_programme(programme)
           .exists?(academic_year:, delivery_site: delivery_site_value)
        "psd"
      elsif delivery_method_value == "nasal_spray"
        "pgd"
      else
        "national"
      end
    else
      "pgd"
    end
  end

  def vaccine_upload_name
    parsed_vaccination_description_string&.dig(:vaccine_name) ||
      vaccine_name&.to_s
  end

  def vaccine
    return if vaccine_upload_name.nil?

    @vaccine ||=
      team.vaccines.find_by(upload_name: vaccine_upload_name) ||
        team.vaccines.find_by(nivs_name: vaccine_upload_name)
  end

  def programmes_by_name
    @programmes_by_name ||=
      team
        .programmes
        .each_with_object({}) do |programme, hash|
          programme.import_names.each do |name|
            # TODO: Handle this in a more generic way to support future
            #  programme variants.
            hash[name.downcase] = if name == "MMRV"
              Programme::Variant.new(programme, variant_type: "mmrv")
            elsif name == "MMR"
              Programme::Variant.new(programme, variant_type: "mmr")
            else
              programme
            end
          end
        end
  end

  delegate :default_dose_sequence,
           :maximum_dose_sequence,
           to: :programme,
           allow_nil: true

  def offline_recording? = session_id.present?

  def imms_api_record?
    uuid.present? &&
      VaccinationRecord.sourced_from_nhs_immunisations_api.exists?(
        uuid: uuid.to_s
      )
  end

  def must_be_current_academic_year? = programme&.flu? || national_reporting?

  def dose_sequence_required? =
    administered && (offline_recording? || national_reporting_hpv?)

  def academic_year = date_of_vaccination&.to_date&.academic_year

  def existing_patients(candidates: nil)
    if patient_first_name.blank? || patient_last_name.blank? ||
         patient_date_of_birth.nil?
      return
    end

    database_matches =
      PatientMatcher.from_relation(
        Patient,
        nhs_number: patient_nhs_number_value,
        given_name: patient_first_name.to_s,
        family_name: patient_last_name.to_s,
        date_of_birth: patient_date_of_birth.to_date,
        address_postcode: patient_postcode&.to_postcode,
        include_3_out_of_4_matches: false
      )

    return database_matches if database_matches.present?

    return if candidates.blank?

    PatientMatcher.from_enumerable(
      candidates,
      nhs_number: patient_nhs_number_value,
      given_name: patient_first_name.to_s,
      family_name: patient_last_name.to_s,
      date_of_birth: patient_date_of_birth.to_date,
      address_postcode: patient_postcode&.to_postcode,
      include_3_out_of_4_matches: false
    )
  end

  def new_patient_attributes
    {
      address_postcode: patient_postcode&.to_postcode,
      date_of_birth: patient_date_of_birth&.to_date,
      birth_academic_year: patient_date_of_birth&.to_date&.academic_year,
      family_name: patient_last_name.to_s,
      given_name: patient_first_name.to_s,
      gender_code: patient_gender_code_value,
      nhs_number: patient_nhs_number_value,
      school: nil
    }.compact
  end

  def administered
    if vaccinated.present?
      if "yes".start_with?(vaccinated.to_s.downcase)
        true
      elsif "no".start_with?(vaccinated.to_s.downcase)
        false
      end
    elsif vaccine_name.present? ||
          combined_vaccination_and_dose_sequence.present? || national_reporting?
      true
    end
  end

  def delivery_site_value
    DELIVERY_SITES[delivery_site&.to_s&.downcase]
  end

  def delivery_method_value
    if delivery_site_value == "nose"
      "nasal_spray"
    elsif delivery_site_value.present?
      "intramuscular"
    end
  end

  def disease_types = vaccine&.disease_types || programme&.disease_types

  def dose_sequence_value
    value =
      parsed_vaccination_description_string&.dig(:dose_sequence) ||
        dose_sequence&.to_s&.gsub(/\s/, "")&.upcase

    return default_dose_sequence if value.blank?

    return value if value.is_a?(Integer)

    dose_sequences = DOSE_SEQUENCES[programme&.type]

    return dose_sequences[value] if dose_sequences&.include?(value)

    dose_sequence&.to_i
  end

  def is_unknown_setting?
    care_setting.blank? && location_type.blank?
  end

  def is_school_setting?
    care_setting&.to_i == CARE_SETTING_SCHOOL ||
      location_type&.to_s&.downcase == "school"
  end

  def is_community_setting?
    care_setting&.to_i == CARE_SETTING_COMMUNITY ||
      (location_type.present? && location_type.to_s.downcase != "school")
  end

  def parsed_vaccination_description_string
    if combined_vaccination_and_dose_sequence.present?
      VaccinationDescriptionStringParser.call(
        combined_vaccination_and_dose_sequence.to_s
      )
    end
  end

  def patient_gender_code_value
    value = patient_gender_code&.to_s&.downcase&.gsub(" ", "_")

    if value.in?(%w[indeterminate unknown])
      "not_known"
    elsif value.in?(Patient.gender_codes.keys)
      value
    end
  end

  def patient_nhs_number_value
    patient_nhs_number&.to_s&.gsub(/\s/, "")
  end

  def reason_not_administered_value
    REASONS_NOT_ADMINISTERED[reason_not_administered&.to_s&.downcase]
  end

  def validate_administered
    return if [true, false].include?(administered)

    if vaccinated.nil?
      errors.add(:base, "<code>VACCINATED</code> is required")
    else
      errors.add(
        vaccinated.header,
        "You need to record whether the child was vaccinated or not. Enter ‘Y’ or ‘N’ in the ‘VACCINATED’ column."
      )
    end
  end

  EARLIEST_BATCH_EXPIRY = Date.new(Date.current.year - 15, 1, 1)
  LATEST_BATCH_EXPIRY = Date.new(Date.current.year + 15, 1, 1)

  def validate_batch_expiry
    if administered
      if batch_expiry.present?
        if (date = batch_expiry.to_date)
          if date > LATEST_BATCH_EXPIRY
            errors.add(
              batch_expiry.header,
              "must be less than 15 years in the future"
            )
          elsif date < EARLIEST_BATCH_EXPIRY
            errors.add(batch_expiry.header, "must be more than 15 years old")
          end
        else
          errors.add(batch_expiry.header, "Enter a date in the correct format.")
        end
      elsif offline_recording? || national_reporting?
        if batch_expiry.nil?
          errors.add(:base, "<code>BATCH_EXPIRY_DATE</code> is required")
        else
          errors.add(batch_expiry.header, "Enter a batch expiry date.")
        end
      end
    elsif batch_expiry.present?
      errors.add(batch_expiry.header, "must be blank")
    end
  end

  def validate_batch_name
    if administered
      if batch_name.present?
        if batch_name.to_s.length > 100
          errors.add(batch_name.header, "must be at most 100 characters long")
        elsif batch_name.to_s.length < 2
          errors.add(batch_name.header, "must be at least 2 characters long")
        elsif batch_name.to_s !~ BatchNumberValidator::FORMAT
          errors.add(batch_name.header, "must be only letters and numbers")
        end
      elsif offline_recording? || national_reporting?
        if batch_name.nil?
          errors.add(
            :base,
            if national_reporting?
              "<code>BATCH_NUMBER</code> is required"
            else
              "<code>BATCH_NUMBER</code> or <code>Vaccination batch number</code> is required"
            end
          )
        elsif batch_name.blank?
          errors.add(batch_name.header, "Enter a batch number.")
        end
      end
    elsif batch_name.present?
      errors.add(batch_name.header, "must be blank")
    end
  end

  def validate_care_setting
    return if care_setting.blank?

    if care_setting.to_i.nil?
      errors.add(care_setting.header, "Enter a valid care setting.")
    elsif ![CARE_SETTING_SCHOOL, CARE_SETTING_COMMUNITY].include?(
          care_setting.to_i
        )
      errors.add(care_setting.header, "Enter a valid care setting.")
    end
  end

  def validate_clinic_name
    clinic_name_required =
      offline_recording? && is_community_setting? && point_of_care?

    if clinic_name.present?
      if clinic_name.to_s.length > MAX_FIELD_LENGTH
        errors.add(
          clinic_name.header,
          "is greater than #{MAX_FIELD_LENGTH} characters long"
        )
      elsif clinic_name_required && clinic.nil?
        errors.add(clinic_name.header, "is not recognised")
      end
    elsif clinic_name_required
      if clinic_name.nil?
        errors.add(
          :base,
          "<code>CLINIC_NAME</code> or <code>Event done at</code> is required"
        )
      elsif clinic_name.blank?
        errors.add(clinic_name.header, "Enter a clinic name.")
      end
    end
  end

  def validate_date_of_vaccination
    if date_of_vaccination.nil?
      errors.add(
        :base,
        if national_reporting?
          "<code>DATE_OF_VACCINATION</code> is required"
        else
          "<code>DATE_OF_VACCINATION</code> or <code>Event date</code> is required"
        end
      )
    elsif date_of_vaccination.blank?
      errors.add(date_of_vaccination.header, "Enter a date.")
    elsif date_of_vaccination.to_date.nil?
      errors.add(
        date_of_vaccination.header,
        "Enter a date in the correct format."
      )
    else
      if patient_date_of_birth&.to_date
        if date_of_vaccination.to_date.future?
          errors.add(
            date_of_vaccination.header,
            "The vaccination date is in the future."
          )
        elsif date_of_vaccination.to_date < patient_date_of_birth.to_date
          errors.add(
            date_of_vaccination.header,
            "The vaccination date is before the date of birth."
          )
        end
      end

      if must_be_current_academic_year? && academic_year != AcademicYear.current
        errors.add(
          date_of_vaccination.header,
          "must be in the current academic year"
        )
      end

      if offline_recording? && session &&
           !session.dates.include?(date_of_vaccination.to_date)
        errors.add(
          date_of_vaccination.header,
          "Enter a date that matches when the vaccination session took place."
        )
      end

      if national_reporting? && team.national_reporting_cut_off_date &&
           date_of_vaccination.to_date < team.national_reporting_cut_off_date
        errors.add(
          date_of_vaccination.header,
          "must be on or after your team's start date with Mavis national reporting: " \
            "#{team.national_reporting_cut_off_date.to_fs(:long)}"
        )
      end
    end
  end

  def validate_delivery_site
    if administered
      if delivery_site.present?
        if delivery_site_value.blank?
          errors.add(delivery_site.header, "Enter a valid anatomical site.")
        elsif (offline_recording? || national_reporting?) && vaccine
          unless vaccine.available_delivery_sites.include?(delivery_site_value)
            errors.add(
              delivery_site.header,
              "Enter a anatomical site that is appropriate for the vaccine."
            )
          end
        end
      elsif offline_recording? || national_reporting?
        if delivery_site.nil?
          errors.add(:base, "<code>ANATOMICAL_SITE</code> is required")
        else
          errors.add(delivery_site.header, "Enter an anatomical site.")
        end
      end
    elsif delivery_site.present?
      errors.add(delivery_site.header, "must be blank")
    end
  end

  def validate_dose_sequence
    return if programme.nil?

    field = dose_sequence || combined_vaccination_and_dose_sequence

    if dose_sequence.present? ||
         parsed_vaccination_description_string&.dig(:dose_sequence).present?
      if dose_sequence_value.nil?
        errors.add(
          field.header,
          "Enter a dose sequence number, for example, 1, 2 or 3."
        )
      elsif maximum_dose_sequence
        if dose_sequence_value < 1
          errors.add(field.header, "must be greater than 0")
        elsif dose_sequence_value > maximum_dose_sequence
          errors.add(
            field.header,
            "must be less than or equal to #{maximum_dose_sequence}"
          )
        end
      end
    elsif dose_sequence_required?
      if field.nil?
        errors.add(
          :base,
          if national_reporting?
            "<code>DOSE_SEQUENCE</code> is required"
          else
            "<code>DOSE_SEQUENCE</code> or <code>Vaccination type</code> is required"
          end
        )
      else
        errors.add(
          field.header,
          "Enter a dose sequence number, for example, 1, 2 or 3. The dose sequence number cannot be greater than 6."
        )
      end
    end
  end

  def validate_existing_patients
    if existing_patients && existing_patients.length > 1
      errors.add(
        :base,
        "Two or more possible patients match the patient first name, last name, date of birth and postcode."
      )
    end
  end

  def validate_local_patient_id
    return unless national_reporting?

    if local_patient_id.nil?
      errors.add(:base, "<code>LOCAL_PATIENT_ID</code> is required")
    elsif local_patient_id.blank?
      errors.add(local_patient_id&.header, "Enter a local patient ID.")
    end
  end

  def validate_local_patient_id_uri
    return unless national_reporting?

    if local_patient_id_uri.nil?
      errors.add(:base, "<code>LOCAL_PATIENT_ID_URI</code> is required")
    elsif local_patient_id_uri.blank?
      errors.add(local_patient_id_uri&.header, "Enter a local patient ID URI.")
    end
  end

  def validate_patient_date_of_birth
    if patient_date_of_birth.nil?
      errors.add(
        :base,
        if national_reporting?
          "<code>PERSON_DOB</code> is required"
        else
          "<code>PERSON_DOB</code> or <code>Date of birth</code> is required"
        end
      )
    elsif patient_date_of_birth.blank?
      errors.add(patient_date_of_birth.header, "Enter a date of birth.")
    elsif patient_date_of_birth.to_date.nil?
      errors.add(
        patient_date_of_birth.header,
        "Enter a date of birth in the correct format."
      )
    elsif patient_date_of_birth.to_date.future?
      errors.add(
        patient_date_of_birth.header,
        "Enter a date of birth in the past."
      )
    end
  end

  def validate_patient_first_name
    if patient_first_name.nil?
      errors.add(
        :base,
        if national_reporting?
          "<code>PERSON_FORENAME</code> is required"
        else
          "<code>PERSON_FORENAME</code> or <code>First name</code> is required"
        end
      )
    elsif patient_first_name.blank?
      errors.add(patient_first_name.header, "Enter a first name.")
    elsif patient_first_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        patient_first_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    end
  end

  def validate_patient_gender_code
    if patient_gender_code.nil?
      errors.add(
        :base,
        if national_reporting?
          "<code>PERSON_GENDER_CODE</code> or <code>PERSON_GENDER</code> is required"
        else
          "<code>PERSON_GENDER_CODE</code>, <code>PERSON_GENDER</code> or <code>Sex</code> is required"
        end
      )
    elsif patient_gender_code.blank?
      errors.add(patient_gender_code.header, "Enter a gender or gender code.")
    elsif patient_gender_code_value.nil?
      errors.add(
        patient_gender_code.header,
        "Enter a valid gender or gender code."
      )
    end
  end

  def validate_patient_last_name
    if patient_last_name.nil?
      errors.add(
        :base,
        if national_reporting?
          "<code>PERSON_SURNAME</code> is required"
        else
          "<code>PERSON_SURNAME</code> or <code>Surname</code> is required"
        end
      )
    elsif patient_last_name.blank?
      errors.add(patient_last_name.header, "Enter a last name.")
    elsif patient_last_name.to_s.length > MAX_FIELD_LENGTH
      errors.add(
        patient_last_name.header,
        "is greater than #{MAX_FIELD_LENGTH} characters long"
      )
    end
  end

  def validate_patient_nhs_number
    return if patient_nhs_number.blank?

    NHSNumberValidator.new(
      allow_blank: true,
      message: "should be a valid NHS number with 10 characters",
      attributes: [patient_nhs_number.header]
    ).validate_each(self, patient_nhs_number.header, patient_nhs_number_value)
  end

  def validate_patient_postcode
    if patient_postcode.present?
      if patient_postcode.to_postcode.nil?
        errors.add(
          patient_postcode.header,
          "Enter a valid postcode, such as SW1A 1AA."
        )
      end
    elsif patient_nhs_number_value.blank? || national_reporting?
      if patient_postcode.nil?
        errors.add(
          :base,
          if national_reporting?
            "<code>PERSON_POSTCODE</code> is required"
          else
            "<code>PERSON_POSTCODE</code> or <code>Postcode</code> is required"
          end
        )
      else
        errors.add(
          patient_postcode.header,
          "Enter a valid postcode, such as SW1A 1AA."
        )
      end
    end
  end

  def validate_performed_by
    if point_of_care?
      if offline_recording?
        if performed_by_user.nil?
          if performed_by_email.nil?
            errors.add(
              :base,
              "<code>PERFORMING_PROFESSIONAL_EMAIL</code> is required"
            )
          else
            errors.add(
              performed_by_email.header,
              "Enter a valid email address."
            )
          end
        end
      elsif performed_by_email.present?
        if performed_by_user.nil?
          errors.add(performed_by_email.header, "Enter a valid email address.")
        end
      end
    elsif national_reporting_flu? && administered
      if performed_by_given_name.nil?
        errors.add(
          :base,
          "<code>PERFORMING_PROFESSIONAL_FORENAME</code> is required"
        )
      elsif performed_by_given_name.blank?
        errors.add(performed_by_given_name.header, "Enter a forename.")
      end

      if performed_by_family_name.nil?
        errors.add(
          :base,
          "<code>PERFORMING_PROFESSIONAL_SURNAME</code> is required"
        )
      elsif performed_by_family_name.blank?
        errors.add(performed_by_family_name.header, "Enter a surname.")
      end
    end
  end

  def validate_performed_ods_code
    if offline_recording? || national_reporting?
      if performed_ods_code.nil?
        errors.add(:base, "<code>ORGANISATION_CODE</code> is required")
      elsif performed_ods_code.blank?
        errors.add(performed_ods_code.header, "Enter an organisation code.")
      elsif performed_ods_code.to_s != organisation.ods_code && point_of_care?
        errors.add(
          performed_ods_code.header,
          "Enter an organisation code that matches the current team."
        )
      end
    end
  end

  def validate_programme
    field = programme_name || combined_vaccination_and_dose_sequence

    if programme
      if national_reporting? &&
           !(national_reporting_hpv? || national_reporting_flu?)
        errors.add(
          vaccine_name.header,
          "This vaccine programme is not accepted in this upload."
        )
      elsif session && !session.programme_types.include?(programme.type)
        errors.add(
          field.header,
          "This programme is not available in this session."
        )
      end
    elsif point_of_care?
      if field.nil?
        errors.add(
          :base,
          "<code>PROGRAMME</code> or <code>Vaccination type</code> is required"
        )
      elsif field.blank?
        errors.add(field.header, "Enter a programme.")
      else
        errors.add(field.header, "This programme is not recognised.")
      end
    end
  end

  def validate_reason_not_administered
    if administered
      if reason_not_administered.present?
        errors.add(reason_not_administered.header, "must be blank")
      end
    elsif reason_not_administered.present?
      if reason_not_administered_value.blank?
        errors.add(reason_not_administered.header, "Enter a valid reason.")
      end
    elsif reason_not_administered.nil?
      errors.add(:base, "<code>REASON_NOT_VACCINATED</code> is required")
    else
      errors.add(reason_not_administered.header, "Enter a valid reason.")
    end
  end

  def validate_school_name
    return if national_reporting?

    school_name_required = school_urn&.to_s == Location::URN_UNKNOWN

    if school_name.present?
      if school_name.to_s.length > MAX_FIELD_LENGTH
        errors.add(
          school_name.header,
          "is greater than #{MAX_FIELD_LENGTH} characters long"
        )
      end
    elsif school_name_required
      if school_name.nil?
        errors.add(
          :base,
          "<code>SCHOOL_NAME</code> or <code>School</code> is required"
        )
      else
        errors.add(school_name.header, "Enter a school name.")
      end
    end
  end

  def validate_school_urn
    return if school_urn.blank? && point_of_care?

    if national_reporting?
      if school_urn.nil?
        errors.add(:base, "<code>SCHOOL_URN</code> is required")
        return
      elsif school_urn.blank?
        errors.add(school_urn.header, "Enter a school URN.")
        return
      end
    end

    school_urn_acceptable =
      school_urn.to_s.in?(
        [Location::URN_HOME_EDUCATED, Location::URN_UNKNOWN]
      ) || Location.school.where_urn_and_site(school_urn.to_s).exists? ||
        Location.school.exists?(systm_one_code: school_urn.to_s)

    unless school_urn_acceptable
      errors.add(
        school_urn.header,
        "The school URN is not recognised. If you’ve checked the URN, " \
          "and you believe it’s valid, contact our support team."
      )
    end
  end

  def validate_session_id
    if session_id.present?
      if uuid.present? &&
           VaccinationRecord.sourced_from_nhs_immunisations_api.exists?(
             uuid: uuid.to_s
           )
        errors.add(
          session_id.header,
          "A session ID cannot be provided for this record; this record was sourced from an external source."
        )
      elsif session_id.to_s != SESSION_ID_CLINIC && session_id.to_i.nil?
        errors.add(
          session_id.header,
          "The session ID is not recognised. Download the offline spreadsheet " \
            "and copy the session ID for this row from there, or " \
            "contact our support team."
        )
      elsif session.nil?
        errors.add(
          session_id.header,
          "The session ID is not recognised. Download the offline spreadsheet " \
            "and copy the session ID for this row from there, or " \
            "contact our support team."
        )
      elsif session.academic_year != academic_year
        errors.add(
          session_id.header,
          "The session ID is not recognised. Download the offline spreadsheet " \
            "and copy the session ID for this row from there, or " \
            "contact our support team."
        )
      end
    end
  end

  def validate_supplied_by
    if supplied_by_email.present? && supplied_by.nil?
      errors.add(supplied_by_email.header, "Enter a valid email address.")
    end
  end

  def validate_time_of_vaccination
    return if time_of_vaccination.blank?

    if time_of_vaccination.to_time.nil?
      errors.add(
        time_of_vaccination.header,
        "Enter a time in the correct format."
      )
    elsif date_of_vaccination&.to_date&.today?
      if performed_at.future?
        errors.add(time_of_vaccination.header, "Enter a time in the past.")
      end
    end
  end

  def validate_uuid
    return if uuid.blank?

    scope =
      VaccinationRecord.left_outer_joins(session: :team_location).where(
        uuid: uuid.to_s
      )

    scope =
      scope.where(team_locations: { team: }).or(
        scope.sourced_from_nhs_immunisations_api
      )

    return if scope.exists?

    errors.add(uuid.header, "Enter an existing record.")
  end

  def validate_vaccine
    field = vaccine_name || combined_vaccination_and_dose_sequence

    if vaccine
      if programme && vaccine.programme_type != programme.type
        errors.add(
          field.header,
          "is not given in the #{programme.name_in_sentence} programme"
        )
      end
    elsif vaccine_upload_name.present?
      errors.add(
        field.header,
        if offline_recording?
          "This vaccine is not available in this session."
        else
          "This vaccine is not valid."
        end
      )
    elsif (offline_recording? || national_reporting?) && administered
      if vaccine_name.nil?
        errors.add(:base, "<code>VACCINE_GIVEN</code> is required")
      elsif vaccine_name.blank?
        errors.add(vaccine_name.header, "Enter a vaccine name.")
      end
    end
  end
end
