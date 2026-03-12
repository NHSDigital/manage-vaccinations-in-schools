# frozen_string_literal: true

class Sessions::InviteToClinicController < Sessions::BaseController
  before_action :authorize_session
  before_action :set_patients_to_invite

  def edit
  end

  def update
    clinic_notifcations =
      @patients_to_invite.filter_map do |patient|
        patient.notifier.send_clinic_invitation(
          @session.programmes_for(patient:),
          team: @session.team,
          academic_year: @session.academic_year,
          sent_by: current_user
        )
      end

    flash[
      :success
    ] = "#{I18n.t("children", count: clinic_notifcations.count)} invited to the clinic"

    redirect_to session_path(@session)
  end

  private

  def authorize_session
    authorize @session, :invite_to_clinic?
  end

  def set_patients_to_invite
    programme_statuses =
      Patient::ProgrammeStatus.statuses.keys -
        Patient::ProgrammeStatus::NOT_ELIGIBLE_STATUSES.keys -
        Patient::ProgrammeStatus::HAS_REFUSAL_STATUSES.keys -
        Patient::ProgrammeStatus::VACCINATED_STATUSES.keys

    academic_year = @session.academic_year

    @patients_to_invite =
      @session
        .patients
        .includes_statuses
        .has_programme_status(
          programme_statuses,
          programme: current_team.programmes,
          academic_year:
        )
        .select do |patient|
          programmes = @session.programmes_for(patient:)

          !patient.invited_to_clinic?(
            programmes,
            team: current_team,
            academic_year:
          ) &&
            patient.notifier.can_send_clinic_invitation?(
              programmes,
              team: current_team,
              academic_year:,
              include_already_invited_programmes: false
            )
        end
  end
end
