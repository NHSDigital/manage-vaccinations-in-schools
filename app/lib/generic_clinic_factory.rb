# frozen_string_literal: true

class GenericClinicFactory
  def initialize(team:, academic_year:)
    @team = team
    @academic_year = academic_year
  end

  def call
    ActiveRecord::Base.transaction do
      location.attach_to_team!(team, academic_year:)
      location.import_year_groups!(
        year_groups,
        academic_year:,
        source: "generic_clinic_factory"
      )
      location.import_default_programme_year_groups!(programmes, academic_year:)
      location
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :team, :academic_year

  delegate :programmes, to: :team

  def location
    @location ||=
      team.generic_clinic ||
        Location.create!(
          name: "Community clinic",
          alternative_name:
            "No known school (including home-schooled children)",
          type: :generic_clinic
        )
  end

  def year_groups = Location::YearGroup::DEFAULT_VALUE_RANGE.to_a
end
