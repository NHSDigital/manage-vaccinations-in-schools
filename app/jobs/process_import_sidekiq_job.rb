# frozen_string_literal: true

class ProcessImportSidekiqJob < ApplicationJobSidekiq
  include SingleConcurrencyConcern

  sidekiq_options queue: :imports

  def perform(import_global_id)
    import = GlobalID::Locator.locate(import_global_id)
    ProcessImportJob.new.perform(import)
  end
end
