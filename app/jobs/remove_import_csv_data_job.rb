# frozen_string_literal: true

class RemoveImportCSVDataJob < ApplicationJobActiveJob
  queue_as :cleanup

  def perform
    cutoff = Settings.retention_days_for.import_csv_data.days.ago

    [ClassImport, CohortImport, ImmunisationImport].each do |import_type|
      import_type
        .csv_not_removed
        .where("created_at < ?", cutoff)
        .find_each(&:remove!)
    end
  end
end
