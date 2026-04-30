# frozen_string_literal: true

class BulkRemoveParentRelationshipsJob < ApplicationJob
  queue_as :imports

  def perform(
    import_global_id,
    parent_relationship_ids_batch,
    user_id,
    remove_option
  )
    import = GlobalID::Locator.locate(import_global_id)
    user = User.find(user_id)

    ActiveRecord::Base.transaction do
      parent_relationships =
        import
          .parent_relationships
          .where(id: parent_relationship_ids_batch)
          .includes(:parent, :patient)

      consents =
        import.parent_relationship_consents(scope: parent_relationships)

      parent_relationships_to_remove =
        if remove_option == "unconsented_only"
          consented_pairs = consents.pluck(:patient_id, :parent_id).to_set

          parent_relationships.reject do |pr|
            consented_pairs.include?([pr.patient_id, pr.parent_id])
          end
        else
          parent_relationships
        end

      invalidate_consents!(user, consents) if remove_option == "all"

      parent_ids_to_check = parent_relationships_to_remove.map(&:parent_id).uniq
      patient_ids = parent_relationships_to_remove.map(&:patient_id)

      parent_relationship_ids = parent_relationships_to_remove.map(&:id)
      ClassImportsParentRelationship.where(
        parent_relationship_id: parent_relationship_ids
      ).delete_all
      CohortImportsParentRelationship.where(
        parent_relationship_id: parent_relationship_ids
      ).delete_all

      Audited
        .audit_class
        .as_user(user) { parent_relationships_to_remove.each(&:destroy!) }

      Parent
        .where(id: parent_ids_to_check)
        .find_each do |parent|
          next if parent.destroyed?
          next if parent.parent_relationships.exists?
          next if parent.consents.exists?

          parent.destroy!
        end

      PatientStatusUpdaterJob.perform_bulk(patient_ids.zip)
    end

    mark_complete_if_finished(import, remove_option)
  end

  private

  def invalidate_consents!(user, consents)
    timestamp = Time.current.to_fs(:long)
    invalidation_note =
      "Consent invalidated on #{timestamp} " \
        "because #{user.full_name} removed all parent-child relationships from an import."

    consents.find_each do |consent|
      consent.update!(notes: invalidation_note, invalidated_at: Time.current)

      consent.update_vaccination_records_no_notify!

      consent.invalidate_all_triages_and_patient_specific_directions!
    end
  end

  def mark_complete_if_finished(import, remove_option)
    return unless import.remaining_parent_relationships(remove_option:).empty?

    import.update!(status: :processed)
  end
end
