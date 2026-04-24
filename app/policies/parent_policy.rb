# frozen_string_literal: true

class ParentPolicy < ApplicationPolicy
  def index? = team.has_point_of_care_access?

  def create? = team.has_point_of_care_access?

  def show? = team.has_point_of_care_access?

  def update? = team.has_point_of_care_access?

  def confirm_destroy? = destroy?

  def destroy? = team.has_point_of_care_access?
end
