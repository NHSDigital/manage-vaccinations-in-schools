# frozen_string_literal: true

class AppPatientSessionConsentComponent < ViewComponent::Base
  def initialize(patient:, session:, programme:)
    @patient = patient
    @session = session
    @programme = programme
    @parents = patient.parents
  end

  private

  attr_reader :patient, :session, :programme, :parents

  delegate :academic_year, :team, to: :session

  delegate :govuk_button_to, to: :helpers

  def programme_type = programme.type

  def colour
    I18n.t(consent_status_value, scope: %i[status consent colour])
  end

  def heading
    status_text = I18n.t(consent_status_value, scope: %i[status consent label])
    "#{consent_status_generator.programme.name}: #{status_text}"
  end

  def consent_status_value
    @consent_status_value ||=
      if consent_status_generator.status == :given
        vaccine_method =
          triage_status_generator.vaccine_method.presence ||
            consent_status_generator.vaccine_methods.first

        without_gelatine =
          triage_status_generator.without_gelatine ||
            consent_status_generator.without_gelatine

        parts = [
          "given",
          vaccine_method,
          without_gelatine ? "without_gelatine" : nil,
          without_gelatine && programme.flu? ? "flu" : nil
        ]

        parts.compact_blank.join("_")
      else
        consent_status_generator.status
      end
  end

  def programme_status
    @programme_status ||= patient.programme_status(programme, academic_year:)
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
        consent_notifications:,
        notify_log_entries:
      )
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
        consent_notifications:,
        notify_log_entries:
      )
  end

  def latest_consent_request
    @latest_consent_request ||= consent_notifications.first
  end

  def consents
    @consents ||=
      patient
        .consents
        .for_programme(programme)
        .where(academic_year:)
        .includes(:consent_form, :parent)
        .order(created_at: :desc)
  end

  def triages
    @triages ||=
      patient
        .triages
        .for_programme(programme)
        .where(academic_year:)
        .not_invalidated
        .order(created_at: :desc)
  end

  def vaccination_records
    @vaccination_records ||=
      patient.vaccination_records.for_programme(programme).order_by_performed_at
  end

  SEND_CONSENT_REQUEST_STATUSES = %i[
    no_response
    request_scheduled
    request_not_scheduled
  ].freeze

  def can_send_consent_request?
    consent_status_value.in?(SEND_CONSENT_REQUEST_STATUSES) &&
      patient.send_notifications?(team: @session.team) &&
      session.can_receive_consent? && patient.parents.any?(&:contactable?)
  end

  def grouped_consents
    @grouped_consents ||=
      ConsentGrouper.call(consents, programme_type:, academic_year:)
  end

  def who_refused
    grouped_consents.find(&:response_refused?)&.who_responded
  end

  def show_health_answers?
    grouped_consents.any?(&:response_given?)
  end

  def consent_notifications
    patient
      .consent_notifications
      .request
      .has_all_programmes_of([programme])
      .for_academic_year(academic_year)
      .order(sent_at: :desc)
  end

  def notify_log_entries
    patient
      .notify_log_entries
      .includes(:notify_log_entry_programmes)
      .for_programme_type(programme_type)
  end
end
