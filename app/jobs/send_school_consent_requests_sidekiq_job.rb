# frozen_string_literal: true

class SendSchoolConsentRequestsSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform(session_id)
    session = Session.find(session_id)
    SendSchoolConsentRequestsJob.new.perform(session)
  end
end
