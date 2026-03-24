# frozen_string_literal: true

class Schools::BaseController < ApplicationController
  before_action :set_location
  before_action :set_academic_year

  layout "full"

  private

  def set_location
    @location =
      policy_scope(Location).where(
        type: %w[school generic_school]
      ).find_by_urn_and_site!(params[:school_urn_and_site])

    authorize @location, policy_class: SchoolPolicy
  end

  def set_academic_year
    @academic_year = AcademicYear.current
  end
end
