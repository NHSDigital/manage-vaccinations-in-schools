# frozen_string_literal: true

class Patients::ProgrammesController < Patients::BaseController
  before_action :set_programme
  before_action :set_academic_year
  before_action :record_access_log_entry, only: :show

  skip_after_action :verify_policy_scoped

  layout "full"

  def show
    authorize @patient
  end

  def invite_to_clinic
    authorize @patient

    @patient.notifier.send_clinic_invitation(
      [@programme],
      team: current_team,
      academic_year: @academic_year,
      sent_by: current_user
    )

    redirect_to patient_programme_path(@patient, @programme.type),
                flash: {
                  success: "#{@patient.full_name} invited to the clinic"
                }
  end

  def record_new_vaccination
    authorize VaccinationRecord.new(patient: @patient), :create?

    @session =
      ActiveRecord::Base.transaction do
        session =
          ClinicSessionFactory.call(
            team: current_team,
            academic_year: @academic_year,
            programme_type: @programme.type
          )

        patient_location =
          PatientLocation.find_or_initialize_by(
            patient: @patient,
            school: session.location,
            academic_year: @academic_year
          )

        if patient_location.new_record?
          patient_location.begin_date = Date.current
          patient_location.end_date = Date.current
        else
          patient_location.extend_date_range_to(Date.current)
        end

        patient_location.save!

        PatientTeamUpdater.call(patient: @patient, team: current_team)

        session
      end

    redirect_to session_patient_programme_path(
                  @session,
                  @patient,
                  @programme.type
                )
  end

  def record_already_vaccinated
    authorize VaccinationRecord.new(patient: @patient), :create?

    draft_vaccination_record =
      DraftVaccinationRecord.new(request_session: session, current_user:)

    draft_vaccination_record.clear_attributes

    dose_sequence =
      @patient.programme_status(
        @programme,
        academic_year: @academic_year
      ).dose_sequence

    first_active_wizard_step =
      if @programme.mmr? && @patient.eligible_for_mmrv?
        :mmr_or_mmrv
      else
        :date_and_time
      end

    programme =
      if @programme.mmr? && !@patient.eligible_for_mmrv?
        Programme::Variant.new(@programme, variant_type: "mmr")
      else
        @programme
      end

    draft_vaccination_record.update!(
      dose_sequence:,
      first_active_wizard_step:,
      location_id: nil,
      location_name: "Unknown",
      outcome: "administered",
      patient: @patient,
      performed_ods_code: current_team.organisation.ods_code,
      programme:,
      reported_by_id: current_user.id,
      source: "manual_report"
    )

    redirect_to draft_vaccination_record_path(
                  first_active_wizard_step.to_s.dasherize
                )
  end

  def send_consent_request
    authorize @patient

    team_location =
      TeamLocation.find_by!(
        team: current_team,
        location: current_team.generic_clinic,
        academic_year: @academic_year
      )

    @patient.notifier.send_consent_request(
      [@programme],
      team_location:,
      sent_by: current_user
    )

    redirect_to patient_programme_path(@patient, @programme.type),
                flash: {
                  success: "Consent request sent."
                }
  end

  private

  def set_programme
    programme_type = params[:programme_type] || params[:type]
    return if programme_type.blank?

    @programme = Programme.find(programme_type, patient: @patient)

    raise ActiveRecord::RecordNotFound if @programme.nil?
  end

  def set_academic_year
    @academic_year = AcademicYear.pending
  end

  def record_access_log_entry
    @patient.access_log_entries.create!(
      user: current_user,
      controller: "patients_programmes",
      action: action_name
    )
  end
end
