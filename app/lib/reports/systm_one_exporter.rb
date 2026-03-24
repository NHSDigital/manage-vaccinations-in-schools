# frozen_string_literal: true

class Reports::SystmOneExporter
  GENDER_CODE_MAPPINGS = {
    male: "M",
    female: "F",
    not_specified: "U",
    not_known: "U"
  }.with_indifferent_access.freeze

  # We think these are CVT3 Read codes still used within SystmOne
  # They have been looked up from the SystmOne Code Browser
  # Some of them are also available online here: https://biobank.ndph.ox.ac.uk/ukb/coding.cgi?id=8708&nl=1
  PRODUCT_DOSE_MAPPINGS = {
    "Cell-based Trivalent Influenza Vaccine Seqirus" => {
      1 => "YcjYj"
    },
    "Fluenz" => {
      1 => "YcjAC"
    },
    "Gardasil 9" => {
      1 => "Y19a4",
      2 => "Y19a5",
      3 => "Y19a6"
    },
    "MenQuadfi" => {
      1 => "YbXKi",
      nil => "YbXKi"
    },
    "Menveo" => {
      1 => "Y0da5",
      nil => "Y0da5"
    },
    "MMR VaxPro" => {
      nil => "Yb9ZN"
    },
    "Nimenrix" => {
      1 => "YOfcf",
      nil => "YOfcf"
    },
    "Priorix" => {
      nil => "Yav8l"
    },
    "Revaxis" => {
      1 => "Y3417",
      2 => "Y3418",
      3 => "Y3400",
      4 => "Y06d3",
      5 => "Y06d4",
      6 => "x05ub",
      nil => "x05ub"
    },
    "Vaxigrip" => {
      1 => "YcjYf"
    },
    "Viatris" => {
      1 => "YcjYh"
    }
  }.freeze

  PROCEDURE_DOSE_MAPPINGS = {
    "mmr" => {
      1 => "65M1.",
      2 => "65MA."
    },
    "mmrv" => {
      1 => "Y3fec",
      2 => "Y3fed"
    }
  }.freeze

  DELIVERY_SITE_MAPPINGS = {
    left_arm_upper_position: "Left deltoid",
    left_arm_lower_position: "Left deltoid",
    left_thigh: "Left lateral thigh",
    right_arm_upper_position: "Right deltoid",
    right_arm_lower_position: "Right deltoid",
    right_thigh: "Right lateral thigh",
    nose: "Nasal"
  }.with_indifferent_access.freeze

  DELIVERY_METHOD_MAPPINGS = {
    intramuscular: "Intramuscular",
    subcutaneous: "Subcutaneous",
    nasal_spray: "Nasal"
  }.with_indifferent_access.freeze

  def initialize(team:, programme:, academic_year:, start_date:, end_date:)
    @team = team
    @programme = programme
    @academic_year = academic_year
    @start_date = start_date
    @end_date = end_date
  end

  def call
    CSV.generate(headers:, write_headers: true) do |csv|
      vaccination_records.find_each do |vaccination_record|
        csv << row(vaccination_record:)
      end
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :team, :programme, :academic_year, :start_date, :end_date

  def headers
    [
      "Practice code",
      "NHS number",
      "Surname",
      "Middle name",
      "Forename",
      "Gender",
      "Date of Birth",
      "House name",
      "House number and road",
      "Town",
      "Postcode",
      "Vaccination",
      "Part",
      "Admin date",
      "Batch number",
      "Expiry date",
      "Dose",
      "Reason",
      "Site",
      "Method",
      "Notes"
    ]
  end

  def vaccination_records
    scope =
      team
        .vaccination_records
        .administered
        .sourced_from_service
        .for_programme(programme)
        .for_academic_year(academic_year)
        .includes(
          :location,
          :patient,
          :performed_by_user,
          :session,
          :supplied_by,
          :vaccine
        )

    if start_date.present?
      scope =
        scope.where(
          "vaccination_records.created_at >= ?",
          start_date.beginning_of_day
        ).or(
          scope.where(
            "vaccination_records.updated_at >= ?",
            start_date.beginning_of_day
          )
        )
    end

    if end_date.present?
      scope =
        scope.where(
          "vaccination_records.created_at <= ?",
          end_date.end_of_day
        ).or(
          scope.where(
            "vaccination_records.updated_at <= ?",
            end_date.end_of_day
          )
        )
    end

    scope
  end

  def row(vaccination_record:)
    patient = vaccination_record.patient

    [
      practice_code(vaccination_record), # Practice code
      patient.nhs_number, # NHS number
      patient.family_name, # Surname
      "", # Middle name (not stored)
      patient.given_name, # Forename
      gender_code(patient.gender_code), # Gender
      patient.date_of_birth.to_fs(:uk_short),
      patient.restricted? ? "" : patient.address_line_2, # House name
      patient.restricted? ? "" : patient.address_line_1, # House number and road
      patient.restricted? ? "" : patient.address_town, # Town
      patient.restricted? ? "" : patient.address_postcode, # Postcode
      vaccination(vaccination_record), # Vaccination
      "", # Part
      vaccination_record.performed_at.to_date.to_fs(:uk_short), # Admin date
      vaccination_record.batch_number, # Batch number
      vaccination_record.batch_expiry&.to_fs(:uk_short), # Expiry date
      vaccination_record.dose_volume_ml, # Dose
      reason(vaccination_record), # Reason (not specified)
      site(vaccination_record), # Site
      method(vaccination_record), # Method
      notes(vaccination_record) # Notes
    ]
  end

  def practice_code(vaccination_record)
    location = vaccination_record.location

    if location&.systm_one_code.present?
      location.systm_one_code
    elsif location&.gias_school?
      location.urn
    elsif location
      location.ods_code
    else
      vaccination_record.session.location.ods_code
    end
  end

  def gender_code(code)
    GENDER_CODE_MAPPINGS[code]
  end

  # TODO: These mappings are valid for Hertforshire, but may not be correct for
  #       other SAIS teams. We'll need to check these are correct with new SAIS
  #       teams.
  def vaccination(vaccination_record)
    return if vaccination_record.not_administered?

    programme = vaccination_record.programme
    vaccine_brand = vaccination_record.vaccine.brand
    dose_sequence = vaccination_record.dose_sequence

    if programme.mmr?
      procedure_mapping =
        PROCEDURE_DOSE_MAPPINGS.dig(programme.variant_type, dose_sequence)
      return procedure_mapping if procedure_mapping.present?
    end

    product_mapping = PRODUCT_DOSE_MAPPINGS.dig(vaccine_brand, dose_sequence)
    return product_mapping if product_mapping.present?

    dose_sequence ? "#{vaccine_brand} Part #{dose_sequence}" : vaccine_brand
  end

  def reason(vaccination_record)
    case vaccination_record.dose_sequence
    when 1, nil
      "Routine"
    else
      "At Risk"
    end
  end

  # TODO: These mappings are valid for Hertforshire, but may not be correct for
  #       other SAIS teams. We'll need to check these are correct with new SAIS
  #       teams.
  def site(vaccination_record)
    return if vaccination_record.not_administered?

    DELIVERY_SITE_MAPPINGS.fetch(vaccination_record.delivery_site)
  end

  def notes(vaccination_record)
    [
      vaccination_record.notes,
      if (user = vaccination_record.performed_by)
        "Administered by: #{user.full_name}"
      end,
      if (user = vaccination_record.supplied_by)
        if vaccination_record.pgd?
          "Authorised by: #{user.full_name}"
        else
          "Prescribed by: #{user.full_name}"
        end
      end
    ].compact_blank.join("\n")
  end

  def method(vaccination_record)
    return if vaccination_record.not_administered?

    DELIVERY_METHOD_MAPPINGS.fetch(vaccination_record.delivery_method)
  end
end
