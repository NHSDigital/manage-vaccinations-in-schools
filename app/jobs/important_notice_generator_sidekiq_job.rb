# frozen_string_literal: true

class ImportantNoticeGeneratorSidekiqJob < ApplicationJobSidekiq
  sidekiq_options queue: :cache

  def perform(patient_ids)
    ImportantNoticeGeneratorJob.new.perform(patient_ids)
  end
end
