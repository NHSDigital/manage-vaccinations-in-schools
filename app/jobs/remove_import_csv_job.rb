# frozen_string_literal: true

class RemoveImportCSVJob < ApplicationJobSidekiq
  sidekiq_options queue: :imports

  def perform
    [ClassImport, CohortImport, ImmunisationImport].each do |import_type|
      import_type
        .csv_not_removed
        .where("created_at < ?", Time.zone.now - 30.days)
        .find_each(&:remove!)
    end
  end
end
