# frozen_string_literal: true

class SchoolMovePolicy < ApplicationPolicy
  def index? = team.has_point_of_care_access?

  def create? = team.has_point_of_care_access?

  def show? = team.has_point_of_care_access?

  def update? = team.has_point_of_care_access?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if team.nil?

      patient_in_team =
        team
          .patients
          .select("1")
          .where("patients.id = school_moves.patient_id")
          .arel
          .exists

      scope
        .where(patient_in_team)
        .where(school: Location.generic_school)
        .or(scope.where(school: team.gias_schools))
        .or(scope.where(school: team.generic_schools))
    end
  end
end
