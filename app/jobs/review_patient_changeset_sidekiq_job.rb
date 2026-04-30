# frozen_string_literal: true

class ReviewPatientChangesetSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :imports

  def perform(patient_changeset_id)
    ReviewPatientChangesetJob.new.perform(patient_changeset_id)
  end
end
