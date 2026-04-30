# frozen_string_literal: true

class SendManualSchoolConsentRemindersJob < ApplicationJob
  include SendSchoolConsentNotificationConcern

  sidekiq_options queue: :notifications

  def perform(session_id, sent_by_user_id)
    session = Session.find(session_id)
    sent_by = User.find(sent_by_user_id)

    patient_programmes_eligible_for_notification(
      session:
    ) do |patient, programmes|
      patient.notifier.send_consent_reminder(programmes, session:, sent_by:)
    end
  end
end
