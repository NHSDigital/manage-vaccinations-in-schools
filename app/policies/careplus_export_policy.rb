# frozen_string_literal: true

class CareplusExportPolicy < ApplicationPolicy
  def index? = team.has_point_of_care_access?

  def show? = team.has_point_of_care_access?

  def download? = show?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.where(team:)
  end
end
