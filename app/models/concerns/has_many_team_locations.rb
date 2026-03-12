# frozen_string_literal: true

module HasManyTeamLocations
  extend ActiveSupport::Concern

  included do
    has_many :team_locations

    has_many :locations, through: :team_locations

    has_many :generic_clinics,
             -> { generic_clinic },
             through: :team_locations,
             source: :location

    has_many :community_clinics,
             -> { community_clinic },
             through: :team_locations,
             source: :location

    has_many :schools,
             -> { school },
             through: :team_locations,
             source: :location
  end
end
