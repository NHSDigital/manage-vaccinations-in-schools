# frozen_string_literal: true

class AppGillickAssessmentComponent < ViewComponent::Base
  def initialize(patient:, session:, programme:)
    @patient = patient
    @session = session
    @programme = programme
  end

  private

  attr_reader :patient, :session, :programme

  delegate :govuk_button_link_to, :policy, to: :helpers

  def gillick_assessment
    @gillick_assessment ||=
      patient
        .gillick_assessments
        .order(created_at: :desc)
        .for_session(session)
        .where(date: Date.current)
        .for_programme(programme)
        .first
  end

  def can_assess?
    @can_assess ||= session.today? && policy(GillickAssessment).new?
  end
end
