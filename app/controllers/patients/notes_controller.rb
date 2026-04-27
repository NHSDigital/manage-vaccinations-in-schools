# frozen_string_literal: true

class Patients::NotesController < Patients::BaseController
  before_action :authorize_patient
  before_action :set_note

  def create
    if @note.update(note_params)
      redirect_to patient_path(@patient), flash: { success: "Note added" }
    else
      render "patients/show", status: :unprocessable_content
    end
  end

  private

  def authorize_patient
    authorize @patient, :show?
  end

  def set_note
    @note = Note.new(created_by: current_user, patient: @patient)
  end

  def note_params = params.expect(note: %i[body])
end
