# frozen_string_literal: true

class SendCareplusExportJob < ApplicationJob
  queue_as :careplus

  retry_on Reports::CareplusSoapSender::ServerError,
           Net::OpenTimeout,
           Net::ReadTimeout,
           Errno::ECONNRESET,
           SocketError,
           wait: :polynomially_longer

  def perform(team_id)
    team = Team.find(team_id)

    # Re-check at execution time in case credentials were removed after enqueue
    unless team.careplus_enabled? && team.careplus_namespace.present? &&
             team.careplus_username.present? && team.careplus_password.present?
      return
    end

    csv =
      Reports::AutomatedCareplusExporter.call(
        team:,
        academic_year: AcademicYear.current,
        start_date: Time.zone.today,
        end_date: Time.zone.today
      )

    Reports::CareplusSoapSender.call(
      csv_payload: csv,
      username: team.careplus_username,
      password: team.careplus_password,
      namespace: team.careplus_namespace
    )
  end
end
