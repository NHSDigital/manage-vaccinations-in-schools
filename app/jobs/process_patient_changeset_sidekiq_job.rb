# frozen_string_literal: true

class ProcessPatientChangesetSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :imports

  def perform(patient_changeset_id)
    ProcessPatientChangesetJob.new.perform(patient_changeset_id)
  end
end
