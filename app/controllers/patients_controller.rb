# frozen_string_literal: true

class PatientsController < ApplicationController
  include PatientSearchFormConcern

  before_action :set_patient_search_form, only: :index
  before_action :set_search_params_present, only: :index
  before_action :set_programmes, only: :index
  before_action :set_programme_statuses, only: :index
  before_action :set_visibility_flags, only: :index
  before_action :set_patient, except: :index
  before_action :record_access_log_entry, only: :show

  layout "full"

  def index
    authorize Patient

    patients =
      if @search_params_present
        scope = policy_scope(Patient).includes_statuses.includes(:school)
        @form.apply(scope)
      else
        skip_policy_scope
        Patient.none
      end

    @show_record_offline = @programmes.present? && @form.invited_to_clinic

    respond_to do |format|
      format.html { @pagy, @patients = pagy(patients) }

      format.xlsx do
        data =
          Reports::OfflineExporter.from_patients(
            patients,
            team: current_team,
            programmes: @programmes,
            academic_year: AcademicYear.current
          )

        filename = "Children exported on #{Date.current.to_fs(:long)}.xlsx"

        send_data(data, filename:, disposition: "attachment")
      end
    end
  end

  def show
  end

  def edit
  end

  def pds_search_history
    latest_results = @patient.pds_search_results.includes(:import).latest_set

    @timeline_items =
      if latest_results.present?
        latest_results
          .map(&:timeline_item)
          .sort_by { |item| item["created_at"] }
      else
        []
      end

    time = latest_results&.last&.import&.processed_at

    if @patient.nhs_number.present?
      @timeline_items << {
        active: true,
        heading_text: "NHS number is #{@patient.nhs_number}",
        description: time&.to_date&.to_fs(:long)
      }
    end
  end

  private

  def set_search_params_present
    @search_params_present = @form.any_filters_applied?
  end

  def set_programmes
    @programmes =
      if current_team.has_national_reporting_access?
        []
      else
        current_team.programmes
      end
  end

  def set_programme_statuses
    @programme_statuses =
      if current_team.has_national_reporting_access?
        []
      else
        Patient::ProgrammeStatus.statuses.keys -
          Patient::ProgrammeStatus::NOT_ELIGIBLE_STATUSES.keys -
          %w[needs_consent_follow_up_requested]
      end
  end

  def set_visibility_flags
    national_reporting_access = current_team.has_national_reporting_access?

    @show_aged_out_of_programmes = !national_reporting_access
    @show_archived_records = !national_reporting_access
    @show_clinic_invitations = !national_reporting_access
    @show_patient_postcode = national_reporting_access
    @show_patient_school = !national_reporting_access
    @show_vaccinated_programme_status_only = national_reporting_access
  end

  def set_patient
    @patient =
      authorize policy_scope(Patient).includes(
                  :gp_practice,
                  :school,
                  :vaccination_records,
                  consents: %i[parent patient],
                  parent_relationships: :parent
                ).find(params[:id])
  end

  def record_access_log_entry
    @patient.access_log_entries.create!(
      user: current_user,
      controller: "patients",
      action: action_name
    )
  end
end
