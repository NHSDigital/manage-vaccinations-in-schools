# frozen_string_literal: true

module VaccinationRecord::NHSImmunisationsAPISync
  extend ActiveSupport::Concern

  included do
    scope :with_correct_source_for_nhs_immunisations_api,
          -> do
            includes(:patient).then do
              if Flipper.enabled?(:sync_national_reporting_to_imms_api)
                it.sourced_from_service.or(it.sourced_from_national_reporting)
              else
                it.sourced_from_service
              end
            end
          end

    scope :sync_all_to_nhs_immunisations_api,
          -> do
            programmes =
              Programme.all_as_variants.select do
                Flipper.enabled?(:imms_api_sync_job, it)
              end

            ids =
              with_correct_source_for_nhs_immunisations_api.for_programmes(
                programmes
              ).pluck(:id)

            VaccinationRecord.where(id: ids).update_all(
              nhs_immunisations_api_sync_pending_at: Time.current
            )

            SyncVaccinationRecordToNHSJob.perform_bulk(ids.zip)
          end

    scope :synced_to_nhs_immunisations_api,
          -> { where.not(nhs_immunisations_api_synced_at: nil) }
    scope :not_synced_to_nhs_immunisations_api,
          -> { where(nhs_immunisations_api_synced_at: nil) }

    before_save :touch_nhs_immunisations_api_sync_pending_at,
                if: :changes_need_to_be_synced_to_nhs_immunisations_api?
    after_commit :queue_sync_to_nhs_immunisations_api
  end

  def correct_source_for_nhs_immunisations_api?
    sourced_from_service? ||
      (
        Flipper.enabled?(:sync_national_reporting_to_imms_api) &&
          sourced_from_national_reporting?
      )
  end

  def should_be_in_nhs_immunisations_api?
    kept? && correct_source_for_nhs_immunisations_api? && administered? &&
      Flipper.enabled?(:imms_api_sync_job, programme) &&
      notify_parents != false && patient.not_invalidated?
  end

  def sync_status
    should_be_synced = should_be_in_nhs_immunisations_api?
    return :not_synced unless should_be_synced

    synced_at = nhs_immunisations_api_synced_at
    pending_at = nhs_immunisations_api_sync_pending_at
    if synced_at.present? && (pending_at.nil? || synced_at > pending_at)
      return :synced
    end

    return :failed if pending_at.present? && 24.hours.ago > pending_at

    :pending
  end

  def changes_need_to_be_synced_to_nhs_immunisations_api?
    changes.present? && !nhs_immunisations_api_etag_changed? &&
      !nhs_immunisations_api_sync_pending_at_changed? &&
      !nhs_immunisations_api_synced_at_changed? &&
      !nhs_immunisations_api_id_changed?
  end

  def touch_nhs_immunisations_api_sync_pending_at
    return unless Flipper.enabled?(:imms_api_sync_job, programme)
    return unless correct_source_for_nhs_immunisations_api?

    self.nhs_immunisations_api_sync_pending_at = Time.current
  end

  def queue_sync_to_nhs_immunisations_api
    return unless Flipper.enabled?(:imms_api_sync_job, programme)
    return unless correct_source_for_nhs_immunisations_api?
    return if nhs_immunisations_api_sync_pending_at.nil?

    if nhs_immunisations_api_synced_at &&
         (
           nhs_immunisations_api_sync_pending_at <
             nhs_immunisations_api_synced_at
         )
      return
    end

    SyncVaccinationRecordToNHSJob.perform_async(id)
  end

  def sync_to_nhs_immunisations_api!
    touch_nhs_immunisations_api_sync_pending_at
    save!

    # The after_commit callback queues the job to actually perform the sync
    # with the API.
  end
end
