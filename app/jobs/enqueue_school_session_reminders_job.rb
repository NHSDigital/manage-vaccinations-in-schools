# frozen_string_literal: true

class EnqueueSchoolSessionRemindersJob < ApplicationJob
  queue_as :notifications

  def perform
    sessions =
      Session
        .includes(:session_programme_year_groups)
        .has_date(Date.tomorrow)
        .joins(:location)
        .merge(Location.gias_school)

    sessions.find_each do |session|
      SendSchoolSessionRemindersJob.perform_later(session)
    end
  end
end
