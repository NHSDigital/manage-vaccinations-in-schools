# frozen_string_literal: true

class EnqueueSchoolConsentRequestsJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform
    sessions =
      Session.send_consent_requests.joins(:location).merge(Location.gias_school)

    sessions.find_each do |session|
      SendSchoolConsentRequestsJob.perform_later(session)
    end
  end
end
