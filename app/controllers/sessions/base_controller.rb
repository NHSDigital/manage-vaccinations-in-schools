# frozen_string_literal: true

class Sessions::BaseController < ApplicationController
  before_action :set_session
  before_action :set_programme_statuses

  private

  def set_session
    @session =
      authorize policy_scope(Session).includes(
                  :session_programme_year_groups
                ).find_by!(slug: params[:session_slug]),
                :show?
  end

  def set_programme_statuses
    @programme_statuses =
      Patient::ProgrammeStatus.statuses.keys -
        Patient::ProgrammeStatus::NOT_ELIGIBLE_STATUSES.keys -
        %w[needs_consent_follow_up_requested]
  end
end
