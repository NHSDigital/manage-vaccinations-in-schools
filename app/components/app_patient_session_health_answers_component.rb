# frozen_string_literal: true

class AppPatientSessionHealthAnswersComponent < ViewComponent::Base
  erb_template <<~ERB
    <% if any_yes_health_answers? %>
      <%= render AppWarningCalloutComponent.new(heading:, level: 2) do %>
        <%= render AppHealthAnswersSummaryComponent.new(grouped_consents) %>
      <% end %>
    <% else %>
      <%= render AppCardComponent.new(section: true) do |card| %>
        <% card.with_heading(level: 2) { heading } %>
        <%= render AppHealthAnswersSummaryComponent.new(grouped_consents) %>
      <% end %>
    <% end %>
  ERB

  def render? = grouped_consents.any?(&:response_given?)

  def initialize(patient:, session:, programme:)
    @patient = patient
    @session = session
    @programme = programme
  end

  private

  attr_reader :patient, :session, :programme

  delegate :academic_year, to: :session

  def heading
    count = yes_health_answers_count
    if count.positive?
      "All answers to health questions, including #{count} #{"Yes response".pluralize(count)}"
    else
      "All answers to health questions"
    end
  end

  def yes_health_answers_count
    grouped_consents.sum do |consent|
      consent.health_answers.count(&:response_yes?)
    end
  end

  def any_yes_health_answers?
    grouped_consents.any? do |consent|
      consent.health_answers.any?(&:response_yes?)
    end
  end

  def grouped_consents
    @grouped_consents ||=
      ConsentGrouper.call(
        patient
          .consents
          .for_programme(programme)
          .where(academic_year:)
          .includes(:consent_form, :parent)
          .order(created_at: :desc),
        programme_type: programme.type,
        academic_year:
      )
  end
end
