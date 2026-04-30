# frozen_string_literal: true

class AppSessionSearchFormComponent < ViewComponent::Base
  STATUSES = %w[in_progress unscheduled scheduled completed cancelled].freeze

  def initialize(form, url:, programmes:, academic_years:)
    @form = form
    @url = url
    @programmes = programmes
    @academic_years = academic_years
  end

  private

  TYPES = {
    "gias_school" => "School session",
    "generic_clinic" => "Community clinic"
  }.freeze

  attr_reader :form, :url, :programmes, :academic_years

  delegate :govuk_button_link_to, to: :helpers

  def statuses
    Flipper.enabled?(:clinic_sessions) ? STATUSES : STATUSES - %w[cancelled]
  end

  def clear_filters_path = "#{@url}?_clear=true"
end
