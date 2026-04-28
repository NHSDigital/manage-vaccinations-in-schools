# frozen_string_literal: true

##
# This class fetches the latitude and longitude of a location's address
# using the +OrdnanceSurvey::PlacesAPI+ and stores it in the position column.
class LocationPositionUpdater
  class MissingAddress < StandardError
  end

  class NoResults < StandardError
  end

  def initialize(location)
    @location = location
  end

  attr_reader :location

  def call
    raise MissingAddress unless location.has_address?

    location.update!(position:)
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  def full_address = location.address_parts.join(", ")

  def position
    response = OrdnanceSurvey::PlacesAPI.find(full_address)

    results = response[:results]
    raise NoResults if results.blank?

    first_result = results.first

    latitude = first_result.dig(:dpa, :lat)
    longitude = first_result.dig(:dpa, :lng)

    raise NoResults if latitude.blank? || longitude.blank?

    "POINT(#{longitude} #{latitude})"
  end
end
