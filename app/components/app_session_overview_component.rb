# frozen_string_literal: true

class AppSessionOverviewComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= render AppSessionStatsComponent.new(session) %>

    <%= render AppSessionVaccinationsComponent.new(session) %>

    <%= render AppSessionActionsComponent.new(session) %>

    <%= render AppSessionDetailsComponent.new(session) %>
  ERB

  def initialize(session)
    @session = session
  end

  private

  attr_reader :session
end
