# frozen_string_literal: true

module DownloadsHelper
  def export_download_path(export)
    download_export_path(export) if export.ready?
  end
end
