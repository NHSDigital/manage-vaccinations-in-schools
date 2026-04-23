# frozen_string_literal: true

class RenameCareplusExportsToReports < ActiveRecord::Migration[8.0]
  def change
    rename_table :careplus_exports, :careplus_reports

    rename_table :careplus_export_vaccination_records,
                 :careplus_report_vaccination_records
    rename_column :careplus_report_vaccination_records,
                  :careplus_export_id,
                  :careplus_report_id
  end
end
