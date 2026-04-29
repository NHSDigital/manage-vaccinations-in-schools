# frozen_string_literal: true

module ImmunisationsAPIThrottlingConcern
  extend ActiveSupport::Concern

  include Sidekiq::Job
  include Sidekiq::Throttled::Job

  included { sidekiq_throttle_as :immunisations_api }
end
