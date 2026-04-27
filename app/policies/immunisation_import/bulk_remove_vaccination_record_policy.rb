# frozen_string_literal: true

class ImmunisationImport::BulkRemoveVaccinationRecordPolicy < ApplicationPolicy
  def create?
    Flipper.enabled?(:import_bulk_remove_vaccination_records)
  end
end
