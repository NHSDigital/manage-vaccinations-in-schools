# frozen_string_literal: true

class LocationPositionUpdaterJob < ApplicationJobSidekiq
  sidekiq_options queue: :third_party_data_imports, lock: :until_executing

  def perform(location_id)
    location = Location.find(location_id)
    LocationPositionUpdater.call(location)
  rescue LocationPositionUpdater::NoResults => e
    if Settings.location_position_updater_job.capture_exception
      Sentry.capture_exception(e, level: "warning")
    else
      Rails.logger.warn(
        "Could not fetch position for: #{location.name} (#{location.id})"
      )
      Rails.logger.warn(e.backtrace.join("\n"))
    end
  end
end
