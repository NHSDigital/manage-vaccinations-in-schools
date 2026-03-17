# frozen_string_literal: true

class AppSessionCardComponent < ViewComponent::Base
  def initialize(
    session,
    patient_count:,
    heading_as_dates: false,
    full_width: false,
    show_buttons: false,
    show_status: false,
    return_to: nil,
    heading_level: 4
  )
    @session = session
    @patient_count = patient_count
    @heading_as_dates = heading_as_dates
    @full_width = full_width
    @show_buttons = show_buttons
    @show_status = show_status
    @return_to = return_to
    @heading_level = heading_level
  end

  def call
    render AppCardComponent.new(link_to:, compact: true) do |card|
      card.with_heading(level: @heading_level) { heading }
      safe_join([summary_list, button_group].compact)
    end
  end

  private

  attr_reader :session,
              :patient_count,
              :heading_as_dates,
              :full_width,
              :show_buttons,
              :show_status,
              :return_to

  delegate :govuk_button_link_to, :govuk_summary_list, to: :helpers
  delegate :programmes, :year_groups, to: :session

  def link_to = session_path(session)

  def heading
    heading_as_dates ? helpers.session_dates(session) : session.location.name
  end

  def summary_list
    render AppSessionSummaryComponent.new(
             session,
             patient_count:,
             full_width:,
             show_dates: !heading_as_dates,
             show_status:
           )
  end

  def button_group
    return unless show_buttons

    tag.div(class: "nhsuk-button-group") do
      govuk_button_link_to "Edit session",
                           edit_session_path(session, return_to:),
                           secondary: true,
                           class: "app-button--small"
    end
  end
end
