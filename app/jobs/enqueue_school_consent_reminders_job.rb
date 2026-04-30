# frozen_string_literal: true

class EnqueueSchoolConsentRemindersJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform
    session_ids =
      Session
        .send_consent_reminders
        .joins(:location)
        .merge(Location.gias_school)
        .ids

    SendAutomaticSchoolConsentRemindersSidekiqJob.perform_bulk(session_ids.zip)
  end
end
