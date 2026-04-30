# frozen_string_literal: true

class SendSchoolSessionRemindersSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform(session_id)
    session = Session.find(session_id)
    SendSchoolSessionRemindersJob.new.perform(session)
  end
end
