# frozen_string_literal: true

class AppSessionSearchFormComponent < ViewComponent::Base
  def initialize(form, url:, programmes:, academic_years:)
    @form = form
    @url = url
    @programmes = programmes
    @academic_years = academic_years
  end

  private

  STATUSES = %w[in_progress unscheduled scheduled completed].freeze

  TYPES = {
    "gias_school" => "School session",
    "generic_clinic" => "Community clinic"
  }.freeze

  attr_reader :form, :url, :programmes, :academic_years

  delegate :govuk_button_link_to, to: :helpers

  def clear_filters_path = "#{@url}?_clear=true"
end
