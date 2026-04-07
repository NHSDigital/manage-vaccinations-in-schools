# frozen_string_literal: true

class AppConsentCardComponent < ViewComponent::Base
  def initialize(consent, session:)
    @consent = consent
    @session = session
  end

  def call
    render AppCardComponent.new(**card_options) do |card|
      card.with_heading(level: 6) { heading }
      render AppConsentSummaryComponent.new(
               consent,
               show_email_address: true,
               show_phone_number: true
             )
    end
  end

  private

  attr_reader :consent, :session

  delegate :patient, :programme, to: :consent
  delegate :govuk_summary_list, to: :helpers

  def link_to
    session_patient_programme_consent_path(session, patient, programme, consent)
  end

  def card_options = { link_to:, colour: "offset", compact: true }

  def heading
    if consent.via_self_consent?
      consent.who_responded
    else
      "#{consent.name} (#{consent.who_responded})"
    end
  end
end
