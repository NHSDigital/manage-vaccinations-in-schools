# frozen_string_literal: true

class AppPatientProgrammeVaccinationComponent < ViewComponent::Base
  def initialize(patient, programme, academic_year:)
    @patient = patient
    @programme = programme
    @academic_year = academic_year
  end

  private

  attr_reader :patient, :programme, :academic_year

  delegate :govuk_button_to,
           :govuk_table,
           :policy,
           :record_already_vaccinated_text,
           :vaccination_record_source,
           to: :helpers

  def programme_type = programme.type

  def vaccination_records
    patient
      .vaccination_records
      .for_programme(programme)
      .includes(:location)
      .order_by_performed_at
      .select { it.show_in_academic_year?(academic_year) }
  end

  def formatted_age_when(vaccination_record)
    age = patient.age_years(now: vaccination_record.performed_at)
    pluralize(age, "year")
  end

  def programme_status_tag
    resolved_status =
      PatientProgrammeStatusResolver.call(
        patient,
        programme_type: programme.type,
        academic_year: AcademicYear.current
      )

    AppAttachedTagsComponent.new(
      resolved_status.fetch(:prefix) => resolved_status
    )
  end

  def can_record_vaccination?
    programme_status = patient.programme_status(programme, academic_year:)

    if programme_status.not_eligible? || programme_status.vaccinated?
      return false
    end

    policy(VaccinationRecord.new(patient:)).new?
  end
end
