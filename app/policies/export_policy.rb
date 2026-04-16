# frozen_string_literal: true

class ExportPolicy < ApplicationPolicy
  def create? = team.has_point_of_care_access?

  def download? = record.team_id == team.id
end
