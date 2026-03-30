# frozen_string_literal: true

class AppPatientProgrammeSessionsComponent < ViewComponent::Base
  def initialize(patient, programme, academic_year:, team:)
    @patient = patient
    @programme = programme
    @academic_year = academic_year
    @team = team
  end

  private

  attr_reader :patient, :programme, :academic_year, :team

  delegate :govuk_button_to, :govuk_table, to: :helpers

  def programme_type = programme.type

  def sessions
    @sessions ||=
      patient
        .sessions
        .where(session_programme_year_groups: { programme_type: })
        .for_team(team)
        .includes(:location, :session_programme_year_groups)
  end

  def session_outcome_tag(session, programme_type)
    vaccination_record =
      session
        .vaccination_records
        .where(programme_type:, patient:)
        .order(:performed_at_date, :performed_at_time)
        .last
    return "No outcome" unless vaccination_record

    helpers.vaccination_record_status_tag(vaccination_record)
  end

  def can_invite_to_clinic?
    return @can_invite_to_clinic if defined?(@can_invite_to_clinic)

    @can_invite_to_clinic =
      patient.notifier.can_send_clinic_invitation?(
        [programme],
        team:,
        academic_year:,
        include_already_invited_programmes: false
      )
  end

  def can_send_clinic_invitation_reminder?
    if defined?(@can_send_clinic_invitation_reminder)
      return @can_send_clinic_invitation_reminder
    end

    @can_send_clinic_invitation_reminder =
      patient.notifier.can_send_clinic_invitation?(
        [programme],
        team:,
        academic_year:
      )
  end

  def can_send_consent_request?
    return @can_send_consent_request if defined?(@can_send_consent_request)

    @can_send_consent_request =
      patient.invited_to_clinic?([programme], team:, academic_year:) &&
        patient.notifier.can_send_consent_request?([programme], academic_year:)
  end
end
