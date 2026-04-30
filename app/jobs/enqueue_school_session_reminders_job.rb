# frozen_string_literal: true

class EnqueueSchoolSessionRemindersJob < ApplicationJobSidekiq
  sidekiq_options queue: :notifications

  def perform
    session_ids =
      Session
        .includes(:session_programme_year_groups)
        .has_date(Date.tomorrow)
        .joins(:location)
        .merge(Location.gias_school)
        .ids

    SendSchoolSessionRemindersSidekiqJob.perform_bulk(session_ids.zip)
  end
end
