# frozen_string_literal: true

class GIASImportJob < ApplicationJobActiveJob
  include SingleConcurrencyConcern

  queue_as :third_party_data_imports

  def perform(dry_run: false)
    GIAS.download

    results = GIAS.check_import
    GIAS.log_import_check_results(results)

    GIAS.import unless dry_run
  end
end
