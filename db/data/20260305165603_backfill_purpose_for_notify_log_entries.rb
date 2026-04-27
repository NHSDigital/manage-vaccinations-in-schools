# frozen_string_literal: true

class BackfillPurposeForNotifyLogEntries < ActiveRecord::Migration[8.1]
  def up
    migration = self.class.name
    started_at = Time.zone.now

    scope = NotifyLogEntry.where(purpose: nil)
    distinct_pairs = scope.distinct.pluck(:template_id, :type)

    records_updated = 0

    Rails.logger.info(
      event: "data_migration_start",
      migration:,
      total_records: scope.count,
      distinct_pairs_count: distinct_pairs.size
    )

    distinct_pairs.each_with_index do |(template_id, type), index|
      template_name = NotifyTemplate.find_by_id(template_id, channel: type.to_sym)&.name
      next unless template_name

      purpose = purpose_for_template_name(template_name)
      next unless purpose

      updated_count = NotifyLogEntry
        .where(purpose: nil, template_id:, type:)
        .update_all(purpose: NotifyLogEntry.purposes.fetch(purpose))

      records_updated += updated_count

      Rails.logger.info(
        event: "data_migration_pair",
        migration:,
        pair_index: index + 1,
        total_pairs: distinct_pairs.size,
        template_id:,
        type:,
        purpose:,
        updated_count:
      )
    end

    duration_minutes = ((Time.zone.now - started_at) / 60.0).round

    Rails.logger.info(
      event: "data_migration_finish",
      migration:,
      duration_minutes:,
      records_updated:
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Inlined from NotifyLogEntry.purpose_for_template_name (removed in MAV-6739)
  # so this historical migration stays runnable if replayed.
  def purpose_for_template_name(template_name_sym)
    name = template_name_sym.to_s

    if name.include?("consent") && name.include?("request")
      :consent_request
    elsif name.include?("consent") && name.include?("reminder")
      :consent_reminder
    elsif name.include?("consent_confirmation")
      :consent_confirmation
    elsif name.include?("consent") && name.include?("warning")
      :consent_warning
    elsif name.include?("clinic") && name.include?("invitation")
      :clinic_invitation
    elsif name.include?("session_school_reminder")
      :session_reminder
    elsif name.include?("triage_vaccination_will_happen")
      :triage_vaccination_will_happen
    elsif name.include?("triage_vaccination_wont_happen")
      :triage_vaccination_wont_happen
    elsif name.include?("triage_vaccination_at_clinic")
      :triage_vaccination_at_clinic
    elsif name.include?("triage_delay_vaccination")
      :triage_delay_vaccination
    elsif name.include?("vaccination_administered")
      :vaccination_administered
    elsif name.include?("vaccination_already_had")
      :vaccination_already_had
    elsif name.include?("vaccination_not_administered")
      :vaccination_not_administered
    elsif name.include?("vaccination_deleted")
      :vaccination_deleted
    end
  end
end
