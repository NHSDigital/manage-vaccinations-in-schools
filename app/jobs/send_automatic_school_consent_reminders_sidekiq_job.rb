# frozen_string_literal: true

class SendAutomaticSchoolConsentRemindersSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform(session_id)
    session = Session.find(session_id)
    SendAutomaticSchoolConsentRemindersJob.new.perform(session)
  end
end
