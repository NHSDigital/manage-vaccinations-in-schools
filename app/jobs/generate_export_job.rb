# frozen_string_literal: true

class GenerateExportJob < ApplicationJobActiveJob
  queue_as :default

  def perform(export)
    return unless export.pending?

    export.update!(file_data: export.exportable.generate_file, status: :ready)
  rescue StandardError => e
    Rails.logger.error(
      "generating data failed for export #{export.to_gid}: #{e.class} - #{e.message}"
    )
    export.failed!
  end
end
