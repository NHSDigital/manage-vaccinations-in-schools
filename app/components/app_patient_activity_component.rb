# frozen_string_literal: true

class AppPatientActivityComponent < ViewComponent::Base
  def initialize(patient, team:)
    @patient = patient
    @team = team
  end

  def call
    render AppCardComponent.new(section: true) do |card|
      card.with_heading { "Activity log" }
      render AppActivityLogComponent.new(patient:, team:)
    end
  end

  private

  attr_reader :patient, :team
end
