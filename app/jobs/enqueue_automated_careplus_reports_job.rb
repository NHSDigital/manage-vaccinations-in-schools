# frozen_string_literal: true

class EnqueueAutomatedCareplusReportsJob
  include Sidekiq::Job

  sidekiq_options queue: :careplus

  def perform
    Team.eligible_for_automated_careplus_reports.ids.each do |team_id|
      SendAutomatedCareplusReportsJob.perform_async(team_id)
    end
  end
end
