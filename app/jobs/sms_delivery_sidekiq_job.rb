# frozen_string_literal: true

class SMSDeliverySidekiqJob < NotifyDeliverySidekiqJob
  include GovukNotifyThrottlingConcern

  def perform(template_name, params)
    SMSDeliveryJob.new.perform(template_name, **fetch_params(params))
  end
end
