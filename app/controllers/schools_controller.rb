# frozen_string_literal: true

class SchoolsController < ApplicationController
  include LocationSearchFormConcern

  before_action :set_location_search_form

  layout "full"

  def index
    authorize Location, policy_class: SchoolPolicy

    locations = @form.apply(policy_scope(Location).school)

    @pagy, @locations = pagy(locations)

    academic_year = AcademicYear.pending

    @patient_count_by_school_id =
      Patient
        .joins(:patient_locations)
        .where(patient_locations: { location: @locations, academic_year: })
        .not_archived(team: current_team)
        .appear_in_programmes(current_team.programmes, academic_year:)
        .distinct
        .group(:school_id)
        .count

    @next_session_date_by_location_id =
      policy_scope(Session)
        .joins(:team_location)
        .joins("CROSS JOIN unnest(dates) date")
        .group("team_location.location_id")
        .where("date >= ?", Date.current)
        .minimum(:date)
  end
end
