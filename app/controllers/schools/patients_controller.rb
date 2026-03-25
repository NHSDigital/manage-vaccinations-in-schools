# frozen_string_literal: true

class Schools::PatientsController < Schools::BaseController
  include PatientSearchFormConcern

  before_action :set_programme_statuses
  before_action :set_patient_search_form

  def index
    scope =
      Patient
        .joins(:patient_locations)
        .where(
          patient_locations: {
            location: @location,
            academic_year: @academic_year
          }
        )
        .where(school: @location)
        .includes_statuses
        .includes(:clinic_notifications)

    patients = @form.apply(scope)

    respond_to do |format|
      format.html { @pagy, @patients = pagy(patients) }

      format.xlsx do
        data =
          Reports::OfflineExporter.from_patients(
            patients,
            team: current_team,
            programmes: @location.programmes,
            academic_year: @academic_year
          )

        location_name =
          if (urn_and_site = @location.urn_and_site).present?
            "#{@location.name} (#{urn_and_site})"
          else
            @location.name
          end

        filename =
          "#{location_name} - exported on #{Date.current.to_fs(:long)}.xlsx"

        send_data(data, filename:, disposition: "attachment")
      end
    end
  end

  private

  def set_programme_statuses
    @programme_statuses =
      Patient::ProgrammeStatus.statuses.keys -
        Patient::ProgrammeStatus::NOT_ELIGIBLE_STATUSES.keys -
        %w[needs_consent_follow_up_requested]
  end
end
