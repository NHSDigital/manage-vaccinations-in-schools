# frozen_string_literal: true

class Reports::ProgrammeVaccinationsExporter
  include Reports::ExportFormatters

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

  delegate :organisation, to: :team

  def headers
    %w[
      ORGANISATION_CODE
      SCHOOL_URN
      SCHOOL_NAME
      CARE_SETTING
      CLINIC_NAME
      PERSON_FORENAME
      PERSON_SURNAME
      PERSON_DATE_OF_BIRTH
      PERSON_DATE_OF_DEATH
      YEAR_GROUP
      PERSON_GENDER_CODE
      PERSON_ADDRESS_LINE_1
      PERSON_POSTCODE
      NHS_NUMBER
      NHS_NUMBER_STATUS_CODE
      GP_ORGANISATION_CODE
      GP_NAME
      CONSENT_STATUS
      CONSENT_DETAILS
      HEALTH_QUESTION_ANSWERS
      TRIAGE_STATUS
      TRIAGED_BY
      TRIAGE_DATE
      TRIAGE_NOTES
      GILLICK_STATUS
      GILLICK_ASSESSMENT_DATE
      GILLICK_ASSESSED_BY
      GILLICK_ASSESSMENT_NOTES
      GILLICK_NOTIFY_PARENTS
      VACCINATED
      DATE_OF_VACCINATION
      TIME_OF_VACCINATION
      PROGRAMME_NAME
      VACCINE_GIVEN
      PROTOCOL
      PERFORMING_PROFESSIONAL_EMAIL
      PERFORMING_PROFESSIONAL_FORENAME
      PERFORMING_PROFESSIONAL_SURNAME
      SUPPLIER_EMAIL
      SUPPLIER_FORENAME
      SUPPLIER_SURNAME
      BATCH_NUMBER
      BATCH_EXPIRY_DATE
      ANATOMICAL_SITE
      ROUTE_OF_VACCINATION
      DOSE_SEQUENCE
      DOSE_VOLUME
      REASON_NOT_VACCINATED
      LOCAL_PATIENT_ID
      SNOMED_PROCEDURE_CODE
      REASON_FOR_INCLUSION
      RECORD_CREATED
      RECORD_UPDATED
    ]
  end

  def vaccination_records
    team
      .vaccination_records
      .sourced_from_service
      .for_programme(programme)
      .for_academic_year(academic_year)
      .created_or_updated_between(start_date, end_date)
      .includes(
        :location,
        :performed_by_user,
        :session,
        :supplied_by,
        :vaccine,
        patient: %i[programme_statuses gp_practice school]
      )
  end

  def consents
    @consents ||=
      Consent
        .for_programme(programme)
        .where(patient_id: vaccination_records.select(:patient_id))
        .not_invalidated
        .includes(:parent, patient: :parent_relationships)
        .group_by(&:patient_id)
        .transform_values do |consents_for_patient|
          ConsentGrouper.call(
            consents_for_patient,
            programme_type: programme.type,
            academic_year:
          )
        end
  end

  def gillick_assessments
    @gillick_assessments ||=
      GillickAssessment
        .select(
          "DISTINCT ON (patient_id, location_id, date) gillick_assessments.*"
        )
        .for_programme(programme)
        .where(
          patient_id: vaccination_records.select(:patient_id),
          location_id: vaccination_records.select(:location_id)
        )
        .order(:patient_id, :location_id, :date, created_at: :desc)
        .includes(:performed_by)
        .group_by(&:patient_id)
        .transform_values do
          it
            .group_by(&:location_id)
            .transform_values { it.group_by(&:date).transform_values(&:first) }
        end
  end

  def triages
    @triages ||=
      Triage
        .select("DISTINCT ON (patient_id) triages.*")
        .for_programme(programme)
        .where(
          academic_year:,
          patient_id: vaccination_records.select(:patient_id)
        )
        .not_invalidated
        .order(:patient_id, created_at: :desc)
        .includes(:performed_by)
        .group_by(&:patient_id)
        .transform_values(&:first)
  end

  def row(vaccination_record:)
    location = vaccination_record.location
    patient = vaccination_record.patient
    session = vaccination_record.session
    vaccine = vaccination_record.vaccine
    date = vaccination_record.performed_at.to_date

    grouped_consents = consents.fetch(patient.id, [])
    triage = triages[patient.id]
    gillick_assessment = gillick_assessments.dig(patient.id, location&.id, date)
    academic_year = session.academic_year

    [
      organisation.ods_code,
      school_urn(location:, patient:),
      school_name(location:, patient:),
      care_setting(location:),
      clinic_name(location:, vaccination_record:),
      patient.given_name,
      patient.family_name,
      patient.date_of_birth.iso8601,
      patient.date_of_death&.iso8601 || "",
      patient.year_group(academic_year:) || "",
      patient.gender_code.humanize,
      patient.restricted? ? "" : patient.address_line_1,
      patient.restricted? ? "" : patient.address_postcode,
      patient.nhs_number,
      nhs_number_status_code(patient:),
      patient.gp_practice&.ods_code || "",
      patient.gp_practice&.name || "",
      consent_status(patient:, programme:, academic_year:),
      consent_details(consents: grouped_consents),
      health_question_answers(consents: grouped_consents),
      triage&.status&.humanize || "",
      triage&.performed_by&.full_name || "",
      triage&.updated_at&.to_date&.iso8601 || "",
      triage&.notes || "",
      gillick_status(gillick_assessment:),
      gillick_assessment&.created_at&.to_date&.iso8601 || "",
      gillick_assessment&.performed_by&.full_name || "",
      gillick_assessment&.notes || "",
      gillick_notify_parents(patient:, gillick_assessment:),
      vaccinated(vaccination_record:),
      vaccination_record.performed_at.to_date.iso8601,
      vaccination_record.performed_at.strftime("%H:%M:%S"),
      vaccination_record.programme.name,
      vaccine&.upload_name || "",
      vaccination_record.protocol || "",
      vaccination_record.performed_by_user&.email || "",
      vaccination_record.performed_by&.given_name || "",
      vaccination_record.performed_by&.family_name || "",
      vaccination_record.supplied_by&.email || "",
      vaccination_record.supplied_by&.given_name || "",
      vaccination_record.supplied_by&.family_name || "",
      vaccination_record.batch_number || "",
      vaccination_record.batch_expiry&.iso8601 || "",
      anatomical_site(vaccination_record:),
      route_of_vaccination(vaccination_record:),
      dose_sequence(vaccination_record:),
      vaccination_record.dose_volume_ml,
      reason_not_vaccinated(vaccination_record:),
      patient.id,
      vaccination_record.snomed_procedure_code,
      reason_for_inclusion(vaccination_record:),
      record_created_at(vaccination_record:),
      record_updated_at(vaccination_record:)
    ]
  end

  def nhs_number_status_code(patient:)
    present = patient.nhs_number.present?
    verified = patient.updated_from_pds_at.present?

    if present && verified
      "01" # Number present and verified
    elsif present
      "02" # Number present but not traced
    else
      "03" # Trace required
    end
  end

  def gillick_notify_parents(patient:, gillick_assessment:)
    return "" if gillick_assessment.nil?

    if (consent = consents[patient.id]&.find(&:via_self_consent?))
      consent.notify_parents_on_vaccination ? "Y" : "N"
    else
      ""
    end
  end

  def reason_for_inclusion(vaccination_record:)
    if start_date.present? && vaccination_record.created_at < start_date
      return "updated"
    end

    "new"
  end

  def record_created_at(vaccination_record:)
    vaccination_record.created_at.iso8601
  end

  def record_updated_at(vaccination_record:)
    return "" if vaccination_record.created_at == vaccination_record.updated_at

    vaccination_record.updated_at.iso8601
  end
end
