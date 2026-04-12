# frozen_string_literal: true

class AppPatientSessionRegistrationComponent < ViewComponent::Base
  def initialize(patient:, session:)
    @patient = patient
    @session = session
  end

  def render?
    session.requires_registration? && session.today?
  end

  private

  attr_reader :patient, :session

  delegate :policy, to: :helpers

  def registration_status
    @registration_status ||= patient.registration_status(session:).status
  end

  def attendance_record
    @attendance_record ||=
      patient
        .attendance_records
        .find_or_initialize_by(location: session.location, date: today)
        .tap { it.session = session }
  end

  def can_edit?
    @can_edit ||= policy(attendance_record).edit?
  end

  def today
    @today ||= session.dates.find(&:today?)
  end
end
