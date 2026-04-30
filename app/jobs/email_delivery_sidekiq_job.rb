# frozen_string_literal: true

class EmailDeliverySidekiqJob < NotifyDeliverySidekiqJob
  include GovukNotifyThrottlingConcern

  def perform(template_name, params)
    EmailDeliveryJob.new.perform(template_name, **fetch_params(params))
  end
end
