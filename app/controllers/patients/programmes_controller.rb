# frozen_string_literal: true

class Patients::ProgrammesController < Patients::BaseController
  before_action :set_programme
  before_action :set_academic_year
  before_action :set_can_invite_to_clinic, only: :show
  before_action :set_can_send_clinic_invitation_reminder, only: :show
  before_action :set_can_send_consent_request, only: :show
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
            location: session.location,
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

  def set_can_invite_to_clinic
    @can_invite_to_clinic =
      @patient.notifier.can_send_clinic_invitation?(
        [@programme],
        team: current_team,
        academic_year: @academic_year,
        include_already_invited_programmes: false
      )
  end

  def set_can_send_clinic_invitation_reminder
    @can_send_clinic_invitation_reminder =
      @patient.notifier.can_send_clinic_invitation?(
        [@programme],
        team: current_team,
        academic_year: @academic_year
      )
  end

  def set_can_send_consent_request
    @can_send_consent_request =
      @patient.invited_to_clinic?(
        [@programme],
        team: current_team,
        academic_year: @academic_year
      ) &&
        @patient.notifier.can_send_consent_request?(
          [@programme],
          academic_year: @academic_year
        )
  end

  def record_access_log_entry
    @patient.access_log_entries.create!(
      user: current_user,
      controller: "patients_programmes",
      action: action_name
    )
  end
end
