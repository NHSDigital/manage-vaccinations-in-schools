# frozen_string_literal: true

class EnqueueAutomatedCareplusReportsJob < ApplicationJob
  sidekiq_options queue: :careplus

  def perform
    ids = Team.eligible_for_automated_careplus_reports.ids
    SendAutomatedCareplusReportsJob.perform_bulk(ids.zip)
  end
end
