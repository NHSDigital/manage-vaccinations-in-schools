# frozen_string_literal: true

class AppLocationSearchFormComponent < ViewComponent::Base
  def initialize(form, url:)
    @form = form
    @url = url
  end

  private

  PHASES = Location::PHASES

  attr_reader :form, :url

  delegate :govuk_button_link_to, to: :helpers

  def clear_filters_path = "#{@url}?_clear=true"
end
