# frozen_string_literal: true

class AppPatientSessionPsdComponent < ViewComponent::Base
  def initialize(patient:, session:, programme:)
    @patient = patient
    @session = session
    @programme = programme
  end

  def render?
    session.psd_enabled?
  end

  private

  attr_reader :patient, :session, :programme

  delegate :academic_year, :team, to: :session

  def psd_status
    has_patient_specific_direction? ? "PSD added" : "PSD not added"
  end

  def has_patient_specific_direction?
    patient
      .patient_specific_directions
      .not_invalidated
      .for_programme(programme)
      .where(team:, academic_year:)
      .exists?
  end
end
