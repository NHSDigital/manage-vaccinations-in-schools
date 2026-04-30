# frozen_string_literal: true

class EnqueueSchoolConsentRemindersJob < ApplicationJobActiveJob
  queue_as :notifications

  def perform
    sessions =
      Session
        .send_consent_reminders
        .joins(:location)
        .merge(Location.gias_school)

    sessions.find_each do |session|
      SendAutomaticSchoolConsentRemindersJob.perform_later(session)
    end
  end
end
