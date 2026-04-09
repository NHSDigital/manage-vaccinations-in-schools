# frozen_string_literal: true

class AppParentCardComponent < ViewComponent::Base
  def initialize(consentable, change_links: {})
    @consentable = consentable
    @change_links = change_links
  end

  def call
    render AppCardComponent.new do |card|
      card.with_heading(level: 2) { "Parent or guardian" }
      render AppConsentParentSummaryComponent.new(@consentable, change_links:)
    end
  end

  def render?
    @consentable.parent_relationship.present? ||
      Flipper.enabled?(:patient_contacts)
  end

  private

  attr_reader :change_links
end
