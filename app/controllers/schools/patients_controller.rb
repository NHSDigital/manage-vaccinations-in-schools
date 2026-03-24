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

    @pagy, @patients = pagy(patients)
  end

  private

  def set_programme_statuses
    @programme_statuses =
      Patient::ProgrammeStatus.statuses.keys -
        %w[
          not_eligible
          needs_consent_request_not_scheduled
          needs_consent_request_scheduled
          needs_consent_request_failed
          needs_consent_follow_up_requested
        ]
  end
end
