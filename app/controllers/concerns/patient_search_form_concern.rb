# frozen_string_literal: true

module PatientSearchFormConcern
  extend ActiveSupport::Concern

  include Pagy::Backend

  def set_patient_search_form
    @form =
      PatientSearchForm.new(
        current_team:,
        request_path: request.path,
        request_session: session,
        session: @session,
        **patient_search_form_params
      )
  end

  private

  def patient_search_form_params
    params.permit(
      :_clear,
      :aged_out_of_programmes,
      :archived,
      :date_of_birth_day,
      :date_of_birth_month,
      :date_of_birth_year,
      :invited_to_clinic,
      :missing_nhs_number,
      :patient_specific_direction_status,
      :programme_status_group,
      :query,
      :registration_status,
      programme_statuses: [],
      programme_types: [],
      vaccine_criteria: [],
      year_groups: []
    )
  end
end
