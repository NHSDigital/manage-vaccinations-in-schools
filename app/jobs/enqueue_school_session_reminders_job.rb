# frozen_string_literal: true

class EnqueueSchoolSessionRemindersJob < ApplicationJob
  sidekiq_options queue: :notifications

  def perform
    session_ids =
      Session
        .includes(:session_programme_year_groups)
        .has_date(Date.tomorrow)
        .joins(:location)
        .merge(Location.gias_school)
        .ids

    SendSchoolSessionRemindersJob.perform_bulk(session_ids.zip)
  end
end
