# frozen_string_literal: true

class PatientSessions::ProgrammesController < PatientSessions::BaseController
  before_action :record_access_log_entry, only: :show

  def show
    render layout: "full"
  end

  def record_already_vaccinated
    authorize VaccinationRecord.new(
                patient: @patient,
                session: @session,
                programme: @programme
              )

    draft_vaccination_record =
      DraftVaccinationRecord.new(request_session: session, current_user:)

    draft_vaccination_record.clear_attributes

    first_active_wizard_step =
      eligible_for_mmr_or_mmrv? ? :mmr_or_mmrv : :date_and_time

    draft_vaccination_record.update!(
      dose_sequence:,
      first_active_wizard_step:,
      location_id: nil,
      location_name: "Unknown",
      outcome: :administered,
      patient: @patient,
      performed_ods_code: current_team.organisation.ods_code,
      programme: programme_for_record_already_vaccinated,
      reported_by_id: current_user.id,
      session: @session,
      source: :manual_report
    )

    redirect_to draft_vaccination_record_path(
                  first_active_wizard_step.to_s.dasherize
                )
  end

  private

  def access_log_entry_action = :show

  def dose_sequence
    if @programme.mmr?
      @patient.programme_status(
        @programme,
        academic_year: @academic_year
      )&.dose_sequence || 1
    end
  end

  def eligible_for_mmr_or_mmrv?
    @programme.mmr? && @patient.eligible_for_mmrv?
  end

  def programme_for_record_already_vaccinated
    if @programme.mmr? && !@patient.eligible_for_mmrv?
      @programme = Programme::Variant.new(@programme, variant_type: "mmr")
    end
    @programme
  end
end
