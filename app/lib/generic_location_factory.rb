# frozen_string_literal: true

##
# Teams are automatically created with three "generic locations" which don't
# represent real physical places.
#
# These are: the generic clinic, the unknown school, and the home-educated
# school.
class GenericLocationFactory
  def initialize(team:, academic_year:)
    @team = team
    @academic_year = academic_year
  end

  def call
    ActiveRecord::Base.transaction do
      locations.map do |location|
        location.attach_to_team!(team, academic_year:)
        location.import_year_groups!(
          year_groups,
          academic_year:,
          source: "generic_location_factory"
        )
        location.import_default_programme_year_groups!(
          programmes,
          academic_year:
        )
        location
      end
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :team, :academic_year

  delegate :programmes, to: :team

  def locations
    [
      generic_clinic_location,
      home_educated_school_location,
      unknown_school_location
    ]
  end

  def year_groups = Location::YearGroup::DEFAULT_VALUE_RANGE.to_a

  def generic_clinic_location
    @generic_clinic_location ||=
      team.generic_clinics.first ||
        Location.create!(name: "Community clinic", type: :generic_clinic)
  end

  def home_educated_school_location
    @home_educated_school_location ||=
      team.generic_schools.find_by(urn: Location::URN_HOME_EDUCATED) ||
        Location.create!(
          name: "Home-educated",
          urn: Location::URN_HOME_EDUCATED,
          type: :generic_school,
          gias_phase: "not_applicable"
        )
  end

  def unknown_school_location
    @unknown_school_location ||=
      team.generic_schools.find_by(urn: Location::URN_UNKNOWN) ||
        Location.create!(
          name: "Unknown school",
          urn: Location::URN_UNKNOWN,
          type: :generic_school,
          gias_phase: "not_applicable"
        )
  end
end
