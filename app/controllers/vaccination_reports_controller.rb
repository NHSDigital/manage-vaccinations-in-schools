# frozen_string_literal: true

class VaccinationReportsController < ApplicationController
  skip_after_action :verify_policy_scoped

  def new
    @vaccination_report =
      authorize VaccinationReport.new(
                  team: current_team,
                  academic_year: AcademicYear.current
                )
  end

  def create
    @vaccination_report =
      authorize VaccinationReport.new(team: current_team, **create_params)

    if @vaccination_report.valid?
      send_data(
        @vaccination_report.csv_data,
        filename: @vaccination_report.csv_filename
      )
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def create_params
    params.expect(
      vaccination_report: %i[
        academic_year
        programme_type
        date_from
        date_to
        file_format
      ]
    )
  end
end
