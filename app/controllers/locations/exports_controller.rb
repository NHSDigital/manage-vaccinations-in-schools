# frozen_string_literal: true

class Locations::ExportsController < ApplicationController
  include PatientSearchFormConcern

  before_action :set_location, only: %i[create]

  skip_after_action :verify_policy_scoped

  def create
    exportable =
      LocationPatientsExport.new(
        location: @location,
        academic_year: AcademicYear.current,
        filter_params: patient_search_form_params.to_h
      )
    @export =
      Export.from_exportable(exportable, user: current_user, team: current_team)

    authorize @export

    @export.save!
    GenerateExportJob.perform_later(@export)
    flash[:success] = {
      heading: t("exports_flash.heading"),
      heading_link_text: t("exports_flash.heading_link_text"),
      heading_link_href: downloads_path
    }
    redirect_to(
      (
        if @location.school?
          school_patients_path(params[:school_urn_and_site])
        else
          patients_path
        end
      )
    )
  end

  private

  def set_location
    @location =
      if params[:school_urn_and_site]
        policy_scope(Location).where(
          type: %w[gias_school generic_school]
        ).find_by_urn_and_site!(params[:school_urn_and_site])
      else
        current_team.generic_clinic
      end
  end
end
