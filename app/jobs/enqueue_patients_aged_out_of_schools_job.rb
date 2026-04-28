# frozen_string_literal: true

class EnqueuePatientsAgedOutOfSchoolsJob < ApplicationJobSidekiq
  sidekiq_options queue: :patients

  def perform
    academic_year = AcademicYear.pending
    ids = Location.gias_school.with_team(academic_year:).pluck(:id)
    PatientsAgedOutOfSchoolJob.perform_bulk(ids.zip)
  end
end
