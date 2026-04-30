# frozen_string_literal: true

require "notifications/client"

# This is a temporary copy of `NotifyDeliveryJob` that will be removed when
# all jobs have been converted to Sidekiq.
class NotifyDeliverySidekiqJob < ApplicationJobSidekiq
  TEAM_ONLY_API_KEY_MESSAGE =
    "Can’t send to this recipient using a team-only API key"

  sidekiq_options queue: :notifications

  def fetch_params(params)
    {
      academic_year: params["academic_year"],
      consent: (id = params["consent_id"]) && Consent.find(id),
      consent_form: (id = params["consent_form_id"]) && ConsentForm.find(id),
      disease_types: params["disease_types"],
      parent: (id = params["parent_id"]) && Parent.find(id),
      patient: (id = params["patient_id"]) && Patient.find(id),
      programme_types: params["programme_types"] || [],
      sent_by: (id = params["sent_by_user_id"]) && User.find(id),
      session: (id = params["session_id"]) && Session.find(id),
      team: (id = params["team_id"]) && Team.find(id),
      team_location: (id = params["team_location_id"]) && TeamLocation.find(id),
      vaccination_record:
        (id = params["vaccination_record_id"]) && VaccinationRecord.find(id)
    }
  end

  def self.client
    @client ||=
      Notifications::Client.new(
        Settings.govuk_notify["#{Settings.govuk_notify.mode}_key"]
      )
  end

  def self.deliveries
    @deliveries ||= []
  end

  def self.send_via_notify? = Settings.govuk_notify&.enabled

  def self.send_via_test? = Rails.env.test?

  class UnknownTemplate < StandardError
  end
end
