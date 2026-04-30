# frozen_string_literal: true

class PatientSessions::ActivitiesController < PatientSessions::BaseController
  before_action :record_access_log_entry, only: :show

  before_action :set_note

  def show
  end

  private

  def set_note
    @note =
      Note.new(created_by: current_user, patient: @patient, session: @session)
  end

  def access_log_entry_action = "log"
end
