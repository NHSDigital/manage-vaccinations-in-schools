# frozen_string_literal: true

class AppPatientSessionTriageComponent < ViewComponent::Base
  def initialize(
    patient:,
    session:,
    programme:,
    current_user:,
    triage_form: nil
  )
    @patient = patient
    @session = session
    @programme = programme
    @current_user = current_user
    @triage_form = triage_form || default_triage_form
    @parents = patient.parents
    @patient_locations =
      patient.patient_locations.includes(
        location: [
          :location_programme_year_groups,
          { team_locations: { sessions: :session_programme_year_groups } }
        ]
      )
  end

  def render?
    consent_status_generator.status == :given ||
      triage_status_generator.status != :not_required
  end

  private

  attr_reader :patient,
              :session,
              :programme,
              :current_user,
              :triage_form,
              :parents,
              :patient_locations

  delegate :academic_year, :team, to: :session

  delegate :govuk_button_link_to, :triage_summary, to: :helpers

  def programme_type = programme.type

  def heading
    "Triage for #{triage_status_generator.programme.name} vaccination"
  end

  def triage_status_value
    @triage_status_value ||=
      if triage_status_generator.status == :safe_to_vaccinate
        vaccine_method = triage_status_generator.vaccine_method
        without_gelatine = triage_status_generator.without_gelatine

        parts = [
          "safe_to_vaccinate",
          vaccine_method,
          without_gelatine ? "without_gelatine" : nil,
          without_gelatine && programme.flu? ? "flu" : nil
        ]

        parts.compact_blank.join("_")
      else
        triage_status_generator.status
      end
  end

  def programme_status
    @programme_status ||= patient.programme_status(programme, academic_year:)
  end

  def triage_status_generator
    @triage_status_generator ||=
      StatusGenerator::Triage.new(
        programme_type:,
        academic_year:,
        patient:,
        consents:,
        triages:,
        vaccination_records:,
        parents:,
        sessions: [session],
        consent_notifications:
      )
  end

  def consent_status_generator
    @consent_status_generator ||=
      StatusGenerator::Consent.new(
        programme_type:,
        academic_year:,
        patient:,
        consents:,
        vaccination_records:,
        parents:,
        sessions: [session],
        consent_notifications:
      )
  end

  def consents
    @consents ||=
      patient.consents.not_invalidated.response_provided.order(
        created_at: :desc
      )
  end

  def triages
    @triages ||=
      patient.triages.includes(:performed_by).order(created_at: :desc)
  end

  def vaccination_records
    @vaccination_records ||=
      patient.vaccination_records.for_programme(programme).order_by_performed_at
  end

  def latest_triage
    @latest_triage ||=
      TriageFinder.call(triages, programme_type:, academic_year:)
  end

  def default_triage_form
    TriageForm.new(patient:, session:, programme:, current_user:)
  end

  def consent_notifications
    patient
      .consent_notifications
      .request
      .has_all_programmes_of([programme])
      .for_academic_year(academic_year)
  end
end
