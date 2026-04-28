# frozen_string_literal: true

class EnqueueLocationPositionUpdaterJob < ApplicationJobSidekiq
  sidekiq_options queue: :third_party_data_imports

  def perform
    ids = Location.where(position: nil).has_address.ids
    LocationPositionUpdaterJob.perform_bulk(ids.zip)
  end
end
