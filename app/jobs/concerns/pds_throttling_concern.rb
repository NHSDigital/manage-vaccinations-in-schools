# frozen_string_literal: true

module PDSThrottlingConcern
  extend ActiveSupport::Concern

  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  included { sidekiq_throttle_as :pds }
end
