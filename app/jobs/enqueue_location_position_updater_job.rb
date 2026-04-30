# frozen_string_literal: true

class EnqueueLocationPositionUpdaterJob < ApplicationJobActiveJob
  queue_as :third_party_data_imports

  def perform
    ids = Location.where(position: nil).has_address.ids
    LocationPositionUpdaterJob.perform_bulk(ids.zip)
  end
end
