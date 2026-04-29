# frozen_string_literal: true

class SendManualSchoolConsentRemindersJob < ApplicationJob
  include SendSchoolConsentNotificationConcern

  queue_as :notifications

  def perform(session, current_user:)
    patient_programmes_eligible_for_notification(
      session:
    ) do |patient, programmes|
      patient.notifier.send_consent_reminder(
        programmes,
        session:,
        sent_by: current_user
      )
    end
  end
end
