# frozen_string_literal: true

class ReviewClassImportSchoolMoveSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :imports

  def perform(import_id)
    ReviewClassImportSchoolMoveJob.new.perform(import_id)
  end
end
