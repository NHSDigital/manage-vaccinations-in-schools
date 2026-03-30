# frozen_string_literal: true

class AppPatientProgrammeActivityComponent < ViewComponent::Base
  def initialize(patient, programme, team:)
    @patient = patient
    @programme = programme
    @team = team
  end

  def call
    render AppCardComponent.new(section: true) do |card|
      card.with_heading { "Programme activity" }
      render AppActivityLogComponent.new(patient:, programme_type:, team:)
    end
  end

  private

  attr_reader :patient, :programme, :team

  def programme_type = programme.type
end
