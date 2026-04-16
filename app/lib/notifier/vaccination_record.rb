# frozen_string_literal: true

class Notifier::VaccinationRecord
  def initialize(vaccination_record)
    @vaccination_record = vaccination_record
  end

  def send_confirmation(sent_by:)
    return if parents.empty?

    template_name =
      if vaccination_record.administered?
        :vaccination_administered
      else
        :vaccination_not_administered
      end

    parents.each do |parent|
      params = { parent:, vaccination_record:, sent_by: }

      EmailDeliveryJob.perform_later(template_name, **params)

      if parent.phone_receive_updates
        SMSDeliveryJob.perform_later(template_name, **params)
      end
    end
  end

  def send_deletion(sent_by:)
    return if parents.empty?

    parents.each do |parent|
      EmailDeliveryJob.perform_later(
        :vaccination_deleted,
        parent:,
        vaccination_record:,
        sent_by:
      )
    end
  end

  private

  attr_reader :vaccination_record

  def parents
    @parents ||= NotificationParentSelector.new(vaccination_record:).parents
  end
end
