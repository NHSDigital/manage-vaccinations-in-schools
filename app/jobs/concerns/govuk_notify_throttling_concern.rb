# frozen_string_literal: true

module GovukNotifyThrottlingConcern
  extend ActiveSupport::Concern

  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  included { sidekiq_throttle_as :govuk_notify }
end
