# frozen_string_literal: true

module HasManyTeamLocations
  extend ActiveSupport::Concern

  included do
    has_many :team_locations

    has_many :locations, through: :team_locations

    has_many :community_clinics,
             -> { distinct.community_clinic },
             through: :team_locations,
             source: :location

    has_many :generic_clinics,
             -> { distinct.generic_clinic },
             through: :team_locations,
             source: :location

    has_many :generic_schools,
             -> { distinct.generic_school },
             through: :team_locations,
             source: :location

    has_many :gias_schools,
             -> { distinct.gias_school },
             through: :team_locations,
             source: :location
  end
end
