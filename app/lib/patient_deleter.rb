# frozen_string_literal: true

class PatientDeleter
  class ProductionDeletionError < StandardError
    def message
      "PatientDeleter requires `confirm_production_delete: true` in production"
    end
  end

  def initialize(patients:, confirm_production_delete: false)
    @patients = patients
    @confirm_production_delete = confirm_production_delete
  end

  def call
    if Rails.env.production? && !@confirm_production_delete
      raise ProductionDeletionError
    end

    ActiveRecord::Base.transaction do
      delete_related(ArchiveReason)
      delete_related(AttendanceRecord)
      delete_related(ClinicNotification)
      delete_related(ConsentNotification)
      delete_related(Consent)
      delete_related(GillickAssessment)
      delete_related(ImportantNotice)
      delete_related(Note)
      delete_related(PatientChangeset)
      delete_related(PatientLocation)
      delete_related(PatientSpecificDirection)
      delete_related(PreScreening)
      delete_related(SchoolMove)
      delete_related(SessionNotification)
      delete_related(Triage)
      delete_related(VaccinationRecord.with_discarded)

      parent_ids =
        Parent.joins(parent_relationships: :patient).merge(@patients).ids
      delete_related(ParentRelationship)
      floating_parents =
        Parent.where(id: parent_ids).where.missing(:parent_relationships)
      Rails.logger.info "Deleting #{floating_parents.count} floating parents"
      floating_parents.destroy_all

      @patients.find_each(&:destroy)
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  def delete_related(scope)
    deletion_scope = scope.joins(:patient).merge(@patients)

    Rails.logger.info "Deleting #{deletion_scope.count} #{scope.name.pluralize}"
    deletion_scope.delete_all
  end
end
