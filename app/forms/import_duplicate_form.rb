# frozen_string_literal: true

class ImportDuplicateForm
  include ActiveModel::Model

  attr_accessor :current_team, :current_user, :object, :apply_changes

  validates :apply_changes, inclusion: { in: :apply_changes_options }

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      case apply_changes
      when "apply"
        apply_pending_changes!
      when "discard"
        discard_pending_changes!
      when "keep_both"
        keep_both_changes!
      end
    end

    reset_count!

    true
  rescue ActiveRecord::RecordInvalid
    errors.add(:base, "Failed to save changes")
    false
  end

  def can_keep_both?
    # Vaccination records have lots of relationships that make it difficult to handle
    object.is_a?(Patient) && object.changesets.none?(&:matched_on_nhs_number)
  end

  def apply_changes_options
    if can_apply?
      can_keep_both? ? %w[apply discard keep_both] : %w[apply discard]
    else
      %w[discard]
    end
  end

  def can_apply?
    !(
      object.is_a?(VaccinationRecord) &&
        object.sourced_from_nhs_immunisations_api?
    )
  end

  def apply_pending_changes!
    return unless can_apply?

    object.patient.apply_pending_changes! if object.respond_to?(:patient)

    object.apply_pending_changes!

    if object.is_a?(Patient)
      PatientChangeLogEntry.log_saved_changes!(
        patient: object,
        user: current_user,
        source: patient_import_source(object)
      )
    end
  end

  def discard_pending_changes!
    object.patient.discard_pending_changes! if object.respond_to?(:patient)

    object.discard_pending_changes!
  end

  def keep_both_changes!
    return unless can_keep_both?
    return unless can_apply?

    object.apply_pending_changes_to_new_record!(
      changeset: changeset_for_pending_changes
    )
  end

  def changeset_for_pending_changes
    scope = object.changesets.includes(:import).order(:created_at)

    completed_import_statuses = %w[
      processed
      partially_processed
      removing_parent_relationships
    ]

    scope
      .processed
      .select { completed_import_statuses.include?(it.import&.status) }
      .last
  end

  def reset_count!
    TeamCachedCounts.new(current_team).reset_import_issues!
  end

  def patient_import_source(_patient)
    import = changeset_for_pending_changes&.import
    import.is_a?(ClassImport) ? :class_import : :cohort_import
  end
end
