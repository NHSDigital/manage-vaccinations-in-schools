# frozen_string_literal: true

class AlreadyHadNotificationSender
  def initialize(vaccination_record:)
    @vaccination_record = vaccination_record
  end

  class EmailDeliveryTracker
    def initialize(template)
      @template = template
      @already_sent_to = Set.new
    end

    def queue(params)
      email_address =
        EmailDeliveryJob.email_address_for(@template, params[:parent])
      return if email_address.nil? || @already_sent_to.include?(email_address)

      @already_sent_to << email_address

      EmailDeliveryJob.perform_later(@template, params)
    end
  end

  class SMSDeliveryTracker
    def initialize(template)
      @template = template
      @already_sent_to = Set.new
    end

    def queue(params)
      phone_number = SMSDeliveryJob.phone_number_for(@template, params[:parent])
      if phone_number.nil? || @already_sent_to.include?(phone_number) ||
           !params[:parent].phone_receive_updates
        return
      end

      @already_sent_to << phone_number

      SMSDeliveryJob.perform_later(@template, params)
    end
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
        vaccination_record: @vaccination_record,
        consents:
      ).parents_with_consent

    email_delivery_tracker = EmailDeliveryTracker.new(:vaccination_already_had)
    sms_delivery_tracker = SMSDeliveryTracker.new(:vaccination_already_had)

    parents_with_consent.each do |parent, consent|
      sms_delivery_tracker.queue(
        parent:,
        vaccination_record: @vaccination_record,
        consent:
      )

      email_delivery_tracker.queue(
        parent:,
        vaccination_record: @vaccination_record,
        consent:
      )

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
