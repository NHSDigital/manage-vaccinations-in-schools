# frozen_string_literal: true

class RemoveExportFileDataJob < ApplicationJobActiveJob
  queue_as :cleanup

  def perform
    cutoff = Settings.retention_days_for.export_file_data.days.ago

    Export
      .not_expired
      .where("created_at < ?", cutoff)
      .update_all(file_data: nil, status: :expired)
  end
end
