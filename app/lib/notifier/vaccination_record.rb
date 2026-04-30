# frozen_string_literal: true

class Notifier::VaccinationRecord
  def initialize(vaccination_record)
    @vaccination_record = vaccination_record
  end

  def send_confirmation(sent_by:)
    return if parents.empty?

    template_name =
      if vaccination_record.administered?
        "vaccination_administered"
      else
        "vaccination_not_administered"
      end

    parents.each do |parent|
      params = {
        "parent_id" => parent.id,
        "vaccination_record_id" => vaccination_record.id,
        "sent_by_user_id" => sent_by&.id
      }

      EmailDeliveryJob.perform_async(template_name, params)

      if parent.phone_receive_updates
        SMSDeliveryJob.perform_async(template_name, params)
      end
    end
  end

  def send_deletion(sent_by:)
    return if parents.empty?

    parents.each do |parent|
      params = {
        "parent_id" => parent.id,
        "vaccination_record_id" => vaccination_record.id,
        "sent_by_user_id" => sent_by&.id
      }

      EmailDeliveryJob.perform_async("vaccination_deleted", params)
    end
  end

  private

  attr_reader :vaccination_record

  def parents
    @parents ||= NotificationParentSelector.new(vaccination_record:).parents
  end
end
