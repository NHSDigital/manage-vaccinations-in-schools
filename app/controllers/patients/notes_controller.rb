# frozen_string_literal: true

class Patients::NotesController < Patients::BaseController
  before_action :authorize_patient
  before_action :set_session
  before_action :set_note

  def create
    if @note.update(note_params)
      if @session
        redirect_to session_patient_activity_path(@session, @patient),
                    flash: {
                      success: "Note added"
                    }
      else
        redirect_to patient_path(@patient), flash: { success: "Note added" }
      end
    elsif @session
      @academic_year = @session.academic_year
      render "patient_sessions/activities/show", status: :unprocessable_content
    else
      render "patients/show", status: :unprocessable_content
    end
  end

  private

  def authorize_patient
    authorize @patient, :show?
  end

  def set_session
    @session = policy_scope(Session).find(params[:session_id]) if params[
      :session_id
    ].present?
  end

  def set_note
    @note =
      Note.new(created_by: current_user, patient: @patient, session: @session)
  end

  def note_params = params.expect(note: %i[body])
end
