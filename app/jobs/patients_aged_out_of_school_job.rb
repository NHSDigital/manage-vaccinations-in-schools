# frozen_string_literal: true

class PatientsAgedOutOfSchoolJob < ApplicationJobSidekiq
  sidekiq_options queue: :patients

  def perform(school_id)
    return if school_id.nil?

    academic_year = AcademicYear.pending

    school =
      Location
        .gias_school
        .includes(:location_year_groups)
        .find_by(id: school_id)

    return if school.nil?

    # Year groups not yet set up for the next academic year.
    if school.location_year_groups.none? { it.academic_year == academic_year }
      return
    end

    team =
      school
        .team_locations
        .includes(:team)
        .ordered
        .find_by(academic_year:)
        &.team

    return if team.nil?

    Patient
      .where(school_id:)
      .find_each do |patient|
        year_group = patient.year_group(academic_year:)

        school_has_year_group =
          school.location_year_groups.any? do
            it.academic_year == academic_year && it.value == year_group
          end

        next if school_has_year_group

        SchoolMove.new(
          patient:,
          school: team.unknown_school,
          academic_year:
        ).confirm!
      end
  end
end
