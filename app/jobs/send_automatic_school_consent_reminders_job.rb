# frozen_string_literal: true

class SendAutomaticSchoolConsentRemindersJob < ApplicationJob
  include SendSchoolConsentNotificationConcern

  queue_as :notifications

  def perform(session)
    patient_programmes_eligible_for_notification(
      session:
    ) do |patient, programmes|
      next unless should_send_notification?(patient:, session:, programmes:)

      patient.notifier.send_consent_reminder(programmes, session:, sent_by: nil)
    end
  end

  def should_send_notification?(patient:, session:, programmes:)
    programmes.any? do |programme|
      initial_request = initial_request(patient:, programme:)
      return false if initial_request.nil?

      date_to_send_reminder =
        earliest_date_to_send_reminder(
          patient:,
          session:,
          programme:,
          initial_request_date: initial_request.sent_at.to_date
        )
      next false if date_to_send_reminder.nil?

      Date.current >= date_to_send_reminder
    end
  end

  def initial_request(patient:, programme:)
    patient
      .consent_notifications
      .sort_by(&:sent_at)
      .find { it.request? && it.programmes.include?(programme) }
  end

  def earliest_date_to_send_reminder(
    patient:,
    session:,
    programme:,
    initial_request_date:
  )
    session_dates_after_request =
      session.dates.select { it > initial_request_date }

    scheduled_automatic_reminder_dates =
      session_dates_after_request.map do
        it - session.days_before_consent_reminders.days
      end

    date_index_to_send_reminder_for =
      already_sent_automatic_consent_reminders_count(patient:, programme:) +
        manual_consent_reminders_replacing_automatic_count(
          patient:,
          programme:,
          scheduled_automatic_reminder_dates:
        )

    if date_index_to_send_reminder_for >=
         scheduled_automatic_reminder_dates.length
      return nil
    end

    scheduled_automatic_reminder_dates[date_index_to_send_reminder_for]
  end

  def already_sent_automatic_consent_reminders_count(patient:, programme:)
    patient.consent_notifications.count do
      it.automated_reminder? && it.programmes.include?(programme)
    end
  end

  def manual_consent_reminders_replacing_automatic_count(
    patient:,
    programme:,
    scheduled_automatic_reminder_dates:
  )
    patient.consent_notifications.count do |notification|
      notification.manual_reminder? &&
        notification.programmes.include?(programme) &&
        scheduled_automatic_reminder_dates.any? do |scheduled_automatic_reminder_date|
          notification.sent_at < scheduled_automatic_reminder_date &&
            notification.sent_at >= scheduled_automatic_reminder_date - 3.days
        end
    end
  end
end
