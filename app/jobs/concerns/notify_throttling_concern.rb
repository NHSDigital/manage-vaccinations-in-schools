# frozen_string_literal: true

module NotifyThrottlingConcern
  extend ActiveSupport::Concern

  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  included do
    sidekiq_throttle_as :govuk_notify

    queue_as :notifications
  end
end
