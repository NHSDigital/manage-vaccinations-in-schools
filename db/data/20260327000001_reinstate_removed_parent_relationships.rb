# frozen_string_literal: true

class ReinstateRemovedParentRelationships < ActiveRecord::Migration[8.1]
  def up
    destroyed_audits =
      Audited::Audit.where(
        auditable_type: "ParentRelationship",
        action: "destroy"
      ).where("created_at > ?", Date.new(2026, 2, 19))

    reinstated = 0

    destroyed_audits.in_batches(of: 1000) do |batch|
      batch.each do |audit|
        changes = audit.audited_changes
        patient_id = changes["patient_id"]
        parent_id = changes["parent_id"]

        next unless Patient.exists?(patient_id)
        next unless Parent.exists?(parent_id)

        # Only reinstate relationships that were removed as part of discarding
        # an import duplicate — identified by a pending_changes clear on the
        # same patient within the same minute.
        contemporaneous_discard =
          Audited::Audit
            .where(
              auditable_type: "Patient",
              auditable_id: patient_id,
              action: "update",
              created_at:
                (audit.created_at - 1.minute)..(audit.created_at + 1.minute)
            )
            .any? do |patient_audit|
              patient_audit.audited_changes.key?("pending_changes") &&
                patient_audit.audited_changes["pending_changes"].second == {}
            end

        next unless contemporaneous_discard

        ParentRelationship.find_or_create_by!(patient_id:, parent_id:) do |pr|
          pr.type = changes["type"]
          pr.other_name = changes["other_name"]
        end

        reinstated += 1
      end
    end

    say "Reinstated #{reinstated} parent relationship(s)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
