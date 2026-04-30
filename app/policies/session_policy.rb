# frozen_string_literal: true

class SessionPolicy < ApplicationPolicy
  def index? = team.has_point_of_care_access?

  def create? = team.has_point_of_care_access?

  def show? = team.has_point_of_care_access?

  def update? = team.has_point_of_care_access?

  def import? = show?

  def invite_to_clinic?
    update? && record.school? && record.completed?
  end

  def manage_consent_reminders?
    update? && record.school?
  end

  def cancel?
    Flipper.enabled?(:clinic_sessions) && record.cancellable? && update?
  end

  def make_in_progress? = update?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.for_team(team)
  end
end
