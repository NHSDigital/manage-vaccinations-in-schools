# frozen_string_literal: true

class UpdateReportingAPITotalsToVersion10 < ActiveRecord::Migration[8.1]
  def change
    update_view :reporting_api_totals,
                version: 10,
                revert_to_version: 9,
                materialized: true
  end
end
