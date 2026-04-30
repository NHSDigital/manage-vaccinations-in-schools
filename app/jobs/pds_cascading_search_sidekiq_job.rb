# frozen_string_literal: true

class PDSCascadingSearchSidekiqJob < ApplicationJobSidekiq
  include PDSThrottlingConcern

  sidekiq_options queue: :pds

  def perform(searchable_global_id, step_name, search_results, queue)
    searchable = GlobalID::Locator.locate(searchable_global_id)
    PDSCascadingSearchJob.new.perform(
      searchable,
      step_name:,
      search_results:,
      queue:
    )
  end
end
