# frozen_string_literal: true

class Schools::InviteToClinicController < Schools::BaseController
  before_action :check_can_send_clinic_invitations
  before_action :set_back_link_path
  before_action :set_programme_statuses
  before_action :set_patients_to_invite
  before_action :set_invitations_count_by_programme_type

  layout "two_thirds"

  def edit
    @form = SchoolInviteToClinicForm.new
  end

  def update
    @form =
      SchoolInviteToClinicForm.new(
        programme_types:
          params.dig(:school_invite_to_clinic_form, :programme_types)
      )

    if @form.valid?
      clinic_notifcations =
        @patients_to_invite.filter_map do |patient|
          patient.notifier.send_clinic_invitation(
            Programme.find_all(@form.programme_types),
            team: current_team,
            academic_year: @academic_year,
            sent_by: current_user,
            include_already_invited_programmes: false
          )
        end

      flash[
        :success
      ] = "#{I18n.t("children", count: clinic_notifcations.count)} invited to the clinic"

      redirect_to @back_link_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def check_can_send_clinic_invitations
    render status: :not_found unless @location.generic_school?
  end

  def set_back_link_path
    @back_link_path = school_patients_path(Location::URN_UNKNOWN)
  end

  def set_programme_statuses
    @programme_statuses =
      Patient::ProgrammeStatus.statuses.keys -
        Patient::ProgrammeStatus::NOT_ELIGIBLE_STATUSES.keys -
        Patient::ProgrammeStatus::HAS_REFUSAL_STATUSES.keys -
        Patient::ProgrammeStatus::VACCINATED_STATUSES.keys
  end

  def set_patients_to_invite
    @patients_to_invite =
      Patient
        .joins(:patient_locations)
        .where(
          patient_locations: {
            location: @location,
            academic_year: @academic_year
          }
        )
        .where(school: @location)
        .not_archived(team: current_team)
        .includes_statuses
        .has_programme_status(
          @programme_statuses,
          programme: current_team.programmes,
          academic_year: @academic_year
        )
  end

  def set_invitations_count_by_programme_type
    @invitations_count_by_programme_type =
      current_team.programmes.index_with do |programme|
        @patients_to_invite
          .includes(:clinic_notifications)
          .has_programme_status(
            @programme_statuses,
            programme:,
            academic_year: @academic_year
          )
          .count do |patient|
            !patient.invited_to_clinic?(
              [programme],
              team: current_team,
              academic_year: @academic_year
            ) &&
              patient.notifier.can_send_clinic_invitation?(
                [programme],
                team: current_team,
                academic_year: @academic_year,
                include_already_invited_programmes: false
              )
          end
      end
  end
end
