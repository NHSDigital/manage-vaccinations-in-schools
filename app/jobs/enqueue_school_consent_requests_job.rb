# frozen_string_literal: true

class EnqueueSchoolConsentRequestsJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform
    session_ids =
      Session
        .send_consent_requests
        .joins(:location)
        .merge(Location.gias_school)
        .ids

    SendSchoolConsentRequestsSidekiqJob.perform_bulk(session_ids.zip)
  end
end
