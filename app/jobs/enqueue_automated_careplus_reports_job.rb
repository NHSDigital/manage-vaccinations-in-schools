# frozen_string_literal: true

class EnqueueAutomatedCareplusReportsJob < ApplicationJob
  queue_as :careplus

  def perform
    ids = Team.eligible_for_automated_careplus_reports.ids
    SendAutomatedCareplusReportsJob.perform_bulk(ids.zip)
  end
end
