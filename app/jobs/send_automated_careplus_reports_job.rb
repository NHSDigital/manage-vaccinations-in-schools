# frozen_string_literal: true

class SendAutomatedCareplusReportsJob
  include Sidekiq::Job

  sidekiq_options queue: :careplus, lock: :until_executed

  def perform(team_id)
    Careplus::AutomatedReportSender.call(team_id:)
  end
end
