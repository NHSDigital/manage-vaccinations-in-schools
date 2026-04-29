# frozen_string_literal: true

require_relative "matchers/notify_sms"

module SMSExpectations
  def expect_sms_to(phone_number, template, nth = :first)
    deliveries = sms_deliveries
    matcher = matching_notify_sms(phone_number:, template:)

    if nth == :any
      expect(deliveries).to include(matcher)
    else
      expect(deliveries.send(nth)).to matcher
    end
  end

  def sms_deliveries
    SMSDeliverySidekiqJob.drain
    SMSDeliveryJob.deliveries
  end
end
