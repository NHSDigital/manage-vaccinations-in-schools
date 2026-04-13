# frozen_string_literal: true

module PendingChangesConcern
  extend ActiveSupport::Concern

  included do
    attribute :pending_changes, :jsonb, default: {}

    scope :with_pending_changes, -> { where.not(pending_changes: {}) }
  end

  def stage_changes(attributes)
    attributes.each do |attr, new_value|
      current_value = public_send(attr)

      if normalised(new_value) == normalised(current_value)
        public_send("#{attr}=", new_value)
        pending_changes.delete(attr.to_s)
      else
        pending_changes[attr.to_s] = new_value
      end
    end
  end

  def with_pending_changes
    return self if pending_changes.blank?

    # Use `becomes` instead of `dup` or `clone` to preserve loaded associations.
    becomes(self.class).tap do |record|
      record.clear_changes_information
      pending_changes.each do |attr, value|
        record.public_send("#{attr}=", value)
      end
    end
  end

  def apply_pending_changes!
    pending_changes.each { |attr, value| public_send("#{attr}=", value) }
    discard_pending_changes!
  end

  def discard_pending_changes!
    self.pending_changes = {}
    save!
  end

  def apply_pending_changes_to_new_record!(changeset:)
    new_record = nil

    ActiveRecord::Base.transaction do
      new_record = dup_for_pending_changes.tap(&:apply_pending_changes!)

      changeset.update!(patient: new_record)

      PDSSearchResult.where(import: changeset.import, patient: self).update_all(
        patient_id: new_record.id
      )
      discard_pending_changes!
    end

    new_record
  end

  private

  def normalised(value)
    if value.is_a?(String)
      value.downcase.normalise_whitespace&.presence
    elsif value.is_a?(Time)
      value.round
    else
      value
    end
  end
end
