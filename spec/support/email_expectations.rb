# frozen_string_literal: true

require_relative "matchers/notify_email"

module EmailExpectations
  def expect_email_to(to, template, nth = :first)
    deliveries = email_deliveries
    matcher = matching_notify_email(to:, template:)

    if nth == :any
      expect(deliveries).to include(matcher)
    else
      expect(deliveries.send(nth)).to matcher
    end
  end

  def email_deliveries
    EmailDeliverySidekiqJob.drain
    EmailDeliveryJob.deliveries
  end
end
