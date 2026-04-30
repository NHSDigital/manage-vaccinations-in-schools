# frozen_string_literal: true

class AppSessionDetailsComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppCardComponent.new do |card| %>
      <% card.with_heading(level: 3, actions:) { "Session details" } %>
      <%= render AppSessionSummaryComponent.new(
          session,
          patient_count: session.patients.count,
          show_consent_forms: true,
          show_dates: true,
          show_location: true,
          show_status: true,
          show_consent_style: true
        ) %>
      <% if helpers.policy(session).edit? %>
        <%= govuk_button_to "Download offline spreadsheet",
                            session_exports_path(session),
                            method: :post,
                            secondary: true %>
      <% end %>
    <% end %>
  ERB

  def initialize(session)
    @session = session
  end

  private

  attr_reader :session

  delegate :govuk_button_to, to: :helpers

  def actions
    return [] unless helpers.policy(session).edit?

    [{ text: "Edit session", href: helpers.edit_session_path(session) }]
  end
end
