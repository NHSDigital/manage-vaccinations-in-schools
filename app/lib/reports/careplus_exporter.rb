# frozen_string_literal: true

class Reports::CareplusExporter
  DOSE_CODES = {
    "mmr" => {
      1 => "1P",
      2 => "1B"
    },
    "td_ipv" => {
      1 => "1P",
      2 => "2P",
      3 => "3P",
      4 => "1B",
      5 => "2B",
      6 => "3B"
    }
  }.freeze

  VACCINE_COLUMN_HEADINGS = {
    vaccine: "Vaccine",
    vaccine_code: "Vaccine Code",
    dose: "Dose",
    reason_not_given: "Reason Not Given",
    site: "Site",
    manufacturer: "Manufacturer",
    batch_number: "Batch No"
  }.freeze

  def initialize(
    team:,
    programmes:,
    academic_year:,
    vaccination_records:,
    include_gender:,
    vaccine_columns:
  )
    @team = team
    @programmes = programmes
    @academic_year = academic_year
    @vaccination_records = vaccination_records
    @include_gender = include_gender
    @vaccine_columns = vaccine_columns
  end

  def call
    CSV.generate(headers:, write_headers: true) do |csv|
      vaccination_records
        .group_by(&:patient)
        .transform_values(&:reverse)
        .each do |patient, vaccination_records|
          rows(patient:, vaccination_records:).each { |row| csv << row }
        end
    end
  end

  def self.call(
    team:,
    programmes:,
    academic_year:,
    start_date:,
    end_date:,
    include_gender:,
    include_missing_nhs_number:,
    vaccine_columns:
  )
    vaccination_records =
      vaccination_records_scope(
        team:,
        programmes:,
        academic_year:,
        start_date:,
        end_date:,
        include_missing_nhs_number:
      ).includes(:patient, :vaccine, session: %i[location team_location])

    from_records(
      vaccination_records:,
      team:,
      programmes:,
      academic_year:,
      include_gender:,
      vaccine_columns:
    )
  end

  def self.from_records(
    vaccination_records:,
    team:,
    programmes:,
    academic_year:,
    include_gender:,
    vaccine_columns:
  )
    new(
      vaccination_records:,
      team:,
      programmes:,
      academic_year:,
      include_gender:,
      vaccine_columns:
    ).call
  end

  def self.vaccination_records_scope(
    team:,
    programmes:,
    academic_year:,
    start_date:,
    end_date:,
    include_missing_nhs_number:
  )
    scope =
      team
        .vaccination_records
        .sourced_from_service
        .for_programmes(programmes)
        .for_academic_year(academic_year)
        .administered
        .order_by_performed_at
        .created_or_updated_between(start_date, end_date)

    scope =
      scope.joins(:patient).merge(
        Patient.with_nhs_number
      ) unless include_missing_nhs_number

    scope
  end

  private_class_method :new

  private

  GENDER_CODE_MAPPINGS = {
    female: "F",
    male: "M",
    not_known: "U",
    not_specified: "I"
  }.with_indifferent_access.freeze

  attr_reader :team,
              :programmes,
              :academic_year,
              :vaccination_records,
              :include_gender,
              :vaccine_columns

  def headers
    [
      "NHS Number",
      "Surname",
      "Forename",
      "Date of Birth",
      "Address Line 1",
      "Person Giving Consent",
      "Ethnicity",
      "Date Attended",
      "Time Attended",
      "Venue Type",
      "Venue Code",
      "Staff Type",
      "Staff Code",
      "Attended",
      "Reason Not Attended",
      "Suspension End Date",
      *vaccine_column_headers(1),
      *vaccine_column_headers(2),
      *vaccine_column_headers(3),
      *vaccine_column_headers(4),
      *vaccine_column_headers(5),
      *gender_headers
    ]
  end

  def vaccine_column_headers(number)
    vaccine_columns.map do |column|
      "#{VACCINE_COLUMN_HEADINGS.fetch(column)} #{number}"
    end
  end

  def gender_headers
    include_gender ? ["Gender"] : []
  end

  def gender_row_value(patient)
    include_gender ? [GENDER_CODE_MAPPINGS[patient.gender_code]] : []
  end

  def consents
    @consents ||=
      Consent
        .select("DISTINCT ON (patient_id) consents.*")
        .for_programmes(programmes)
        .where(patient: vaccination_records.select(:patient_id), academic_year:)
        .not_invalidated
        .response_given
        .order(:patient_id, created_at: :desc)
        .includes(:parent, :patient)
        .group_by(&:patient_id)
        .transform_values(&:first)
  end

  def rows(patient:, vaccination_records:)
    vaccination_records
      .group_by(&:session)
      .flat_map do |session, records_in_same_session|
        records_in_same_session
          .group_by { it.performed_at.to_date }
          .map do |date, records|
            [
              patient.nhs_number,
              patient.family_name,
              patient.given_name,
              patient.date_of_birth.strftime("%d/%m/%Y"),
              patient.restricted? ? "" : patient.address_line_1,
              consents[patient.id]&.name || "",
              # We use an empty value for ethnicity, rather than the official unknown value of 99,
              # to prevent overwriting existing values in CarePlus
              "",
              date.strftime("%d/%m/%Y"),
              records.first.performed_at.strftime("%H:%M"),
              session.location.gias_school? ? "SC" : "CL", # Venue Type
              session.location.dfe_number || team.careplus_venue_code, # Venue Code
              team.careplus_staff_type,
              team.careplus_staff_code,
              "Y", # Attended; Did not attends do not get recorded on GP systems
              "", # Reason Not Attended; Always blank
              "", # Suspension End Date; Doesn't need to be used
              *vaccine_fields(records, 0),
              *vaccine_fields(records, 1),
              *vaccine_fields(records, 2),
              *vaccine_fields(records, 3),
              *vaccine_fields(records, 4),
              *gender_row_value(patient)
            ]
          end
      end
  end

  def blank_vaccine_fields
    Array.new(vaccine_columns.length, "")
  end

  def vaccine_fields(vaccination_records, index)
    record = vaccination_records[index]
    return blank_vaccine_fields unless record

    vaccine_columns.map { |column| vaccine_field_value(column, record) }
  end

  def vaccine_field_value(column, record)
    case column
    when :vaccine
      record.vaccine.snomed_product_code
    when :vaccine_code
      vaccine_code(record)
    when :dose
      dose_sequence_code(record)
    when :reason_not_given
      ""
    when :site
      coded_site(record.delivery_site)
    when :manufacturer
      record.vaccine.manufacturer
    when :batch_number
      record.batch_number
    else
      raise "Unknown vaccine column: #{column}"
    end
  end

  # Official list of Careplus codes
  # AB: Abdomen
  # ALT: Anterolateral Thigh
  # L: Left
  # LA: Left Arm
  # LALT: Left Upper Anterolateral Thigh
  # LB: Left Buttock
  # LL: Left Leg
  # LLIF: Left Lower Inside Forearm
  # LT: Left Thigh
  # MOU: Mouth
  # N: Nasal
  # NA: Not Applicable
  # NK: Not Known
  # O: Other
  # R: Right
  # RA: Right Arm
  # RALT: Right Upper Anterolateral Thigh
  # RB: Right Buttock
  # RL: Right Leg
  # RLIF: Right Lower Inside Forearm
  # RT: Right Thigh
  # U: Unconfirmed
  # UA: Upper Arm
  # ULA: Upper Left Arm
  # URA: Upper Right Arm
  def coded_site(site)
    {
      left_arm_upper_position: "ULA",
      left_arm_lower_position: "ULA",
      right_arm_upper_position: "URA",
      right_arm_lower_position: "URA",
      left_thigh: "LT",
      right_thigh: "RT",
      left_buttock: "LB",
      right_buttock: "RB",
      nose: "N"
      # We don't implement the other codes currently
    }.fetch(site.to_sym)
  end

  def dose_sequence_code(record)
    return "" if record.dose_sequence.blank?

    if (dose_codes = DOSE_CODES[record.programme.type])
      dose_codes.fetch(record.dose_sequence) do
        raise "Unexpected dose sequence: #{record.dose_sequence}"
      end
    else
      "#{record.dose_sequence}P"
    end
  end

  def vaccine_code(vaccination_record)
    programme = vaccination_record.programme

    if programme.flu? && vaccination_record.delivery_method_nasal_spray?
      "FLUENZ"
    elsif programme.flu?
      "FLU"
    elsif programme.hpv?
      "HPV"
    elsif programme.menacwy?
      "ACWYX4"
    elsif programme.mmr?
      programme.mmrv_variant? ? "MMRV" : "MMR"
    elsif programme.td_ipv?
      "3IN1"
    else
      raise "Unknown programme: #{programme.type}"
    end
  end
end
