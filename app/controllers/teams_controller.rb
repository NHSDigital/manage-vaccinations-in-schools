# frozen_string_literal: true

class TeamsController < ApplicationController
  skip_after_action :verify_policy_scoped
  before_action :set_team
  before_action :set_schools, only: :schools
  before_action :set_clinics, only: :clinics

  layout "full"

  def contact_details
  end

  def sessions
  end

  def schools
  end

  def clinics
  end

  private

  def set_team
    @team = authorize current_team
  end

  def set_schools
    @schools =
      @team
        .gias_schools # TODO: schools
        .joins(:team_locations)
        .where(team_locations: { academic_year: AcademicYear.pending })
        .distinct
        .order(:name)
  end

  def set_clinics
    @clinics =
      @team
        .community_clinics
        .joins(:team_locations)
        .where(team_locations: { academic_year: AcademicYear.pending })
        .distinct
        .order(:name)
  end
end
