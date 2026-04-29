# frozen_string_literal: true

class AlreadyHadNotificationSender
  def initialize(vaccination_record:)
    @vaccination_record = vaccination_record
  end

  def call
    return if vaccination_record.sourced_from_service?
    return if was_already_vaccinated?
    return if is_still_eligible_for_vaccination?

    consents = patient.consents.includes(:parent, :team)

    consents =
      consents.where(
        "patient_already_vaccinated_notification_sent_at < ?",
        vaccination_record.created_at
      ).or(
        consents.where(
          "patient_already_vaccinated_notification_sent_at IS NULL"
        )
      )

    parents_with_consent =
      NotificationParentSelector.new(
        vaccination_record:,
        consents:
      ).parents_with_consent

    parents_with_consent.each do |parent, consent|
      params = {
        "parent_id" => parent.id,
        "vaccination_record_id" => vaccination_record.id,
        "consent_id" => consent.id
      }

      if parent.phone_receive_updates
        SMSDeliverySidekiqJob.perform_async("vaccination_already_had", params)
      end

      EmailDeliverySidekiqJob.perform_async("vaccination_already_had", params)

      consent.update!(
        patient_already_vaccinated_notification_sent_at: Time.current
      )
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :vaccination_record

  delegate :patient, :programme_type, :programme, to: :vaccination_record

  def academic_year = AcademicYear.current

  def previous_vaccination_records
    # We need to ensure there is a deterministic order of vaccination records on
    # a child so that the :already_vaccinated_notification is sent once and only
    # once per child. Using created_at alone is not sufficient as batching
    # allows for multiple vaccination records to be created with the same
    # created_at timestamp. We chose the ID as a tie-breaker since IDs are
    # unique and sequential.
    patient.vaccination_records.where(
      "(created_at < :created_at) OR (created_at = :created_at AND id < :id)",
      created_at: vaccination_record.created_at,
      id: vaccination_record.id
    )
  end

  def was_already_vaccinated?
    VaccinationCriteria.new(
      programme_type:,
      academic_year:,
      patient:,
      vaccination_records: previous_vaccination_records
    ).vaccinated?
  end

  def is_still_eligible_for_vaccination?
    !patient.programme_status(programme, academic_year:).vaccinated?
  end
end
