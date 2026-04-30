# frozen_string_literal: true

class SendVaccinationConfirmationsJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform
    # Find the oldest record that has had a confirmation sent, and send confirmations for all subsequent records
    since =
      VaccinationRecord.kept.confirmation_sent.maximum(:created_at) ||
        24.hours.ago
    academic_year = AcademicYear.current

    VaccinationRecord
      .includes(patient: { consents: :parent })
      .kept
      .confirmation_not_sent
      .where("created_at >= ?", since)
      .sourced_from_service
      .select { it.academic_year == academic_year }
      .each { send_vaccination_confirmation(it) }
  end

  def send_vaccination_confirmation(vaccination_record)
    vaccination_record.notifier.send_confirmation(sent_by: nil)
    vaccination_record.update_column(:confirmation_sent_at, Time.current)
  end
end
