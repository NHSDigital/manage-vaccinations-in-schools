# frozen_string_literal: true

class PatientSessions::ProgrammesController < PatientSessions::BaseController
  before_action :record_access_log_entry, only: :show

  layout "full"

  def show
  end

  private

  def access_log_entry_action = :show
end
