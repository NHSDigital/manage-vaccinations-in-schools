# frozen_string_literal: true

class ImportantNoticeGeneratorJob < ApplicationJobActiveJob
  queue_as :cache

  BATCH_SIZE = 1000

  STATUS_NOTICE_RECORDED_AT_FIELDS = {
    deceased: :date_of_death_recorded_at,
    invalidated: :invalidated_at,
    restricted: :restricted_at
  }.freeze

  def perform(patient_ids)
    scope = Patient.includes(:teams, vaccination_records: %i[team])

    if patient_ids.present?
      process_batch(scope.where(id: patient_ids))
    else
      scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
        process_batch(batch)
      end
    end
  end

  private

  def process_batch(patients)
    notices_to_create = []
    notice_ids_to_dismiss = []

    existing_notices =
      ImportantNotice
        .where(patient_id: patients.map(&:id), dismissed_at: nil)
        .index_by { notice_key(it) }

    patients.each do |patient|
      team_ids = patient.teams.map(&:id)

      next if team_ids.empty?

      team_ids.each do |team_id|
        add_notices_based_on_patient_status(
          patient,
          team_id,
          existing_notices,
          notices_to_create
        )
        dismiss_existing_notices_based_on_patient_status(
          patient,
          team_id,
          existing_notices,
          notice_ids_to_dismiss
        )
        add_gillick_no_notify_notices(
          patient,
          team_id,
          existing_notices,
          notices_to_create
        )
        dismiss_team_changed_notices(patient, notice_ids_to_dismiss)
      end
    end

    if notices_to_create.any?
      ImportantNotice.import!(notices_to_create, on_duplicate_key_ignore: true)
    end

    if notice_ids_to_dismiss.any?
      ImportantNotice.where(id: notice_ids_to_dismiss).update_all(
        dismissed_at: Time.current
      )
    end
  end

  def add_notices_based_on_patient_status(
    patient,
    team_id,
    existing_notices,
    notices_to_create
  )
    STATUS_NOTICE_RECORDED_AT_FIELDS.each do |type, recorded_at_method|
      next unless patient.public_send("#{type}?")

      next if existing_notices.key?(notice_key_for(patient.id, type, team_id))

      notices_to_create << ImportantNotice.new(
        patient:,
        team_id:,
        type:,
        recorded_at: patient.public_send(recorded_at_method)
      )
    end
  end

  def dismiss_existing_notices_based_on_patient_status(
    patient,
    team_id,
    existing_notices,
    notice_ids_to_dismiss
  )
    STATUS_NOTICE_RECORDED_AT_FIELDS.each_key do |type|
      next if patient.public_send("#{type}?")

      existing_notices.each_value do |notice|
        unless notice.patient_id == patient.id && notice.team_id == team_id &&
                 notice.type == type.to_s
          next
        end

        notice_ids_to_dismiss << notice.id
      end
    end
  end

  def add_gillick_no_notify_notices(
    patient,
    team_id,
    existing_notices,
    notices_to_create
  )
    patient.vaccination_records.each do |record|
      next unless record.team&.id == team_id && record.notify_parents == false

      if existing_notices.key?(
           notice_key_for(patient.id, :gillick_no_notify, team_id, record.id)
         )
        next
      end

      notices_to_create << ImportantNotice.new(
        patient:,
        team_id:,
        vaccination_record_id: record.id,
        type: :gillick_no_notify,
        recorded_at: record.performed_at
      )
    end
  end

  def dismiss_team_changed_notices(patient, notice_ids_to_dismiss)
    team_changed_notices = patient.important_notices.team_changed
    return unless team_changed_notices.any?

    current_teams = patient.teams_via_patient_locations

    if current_teams.any?
      notice_ids_to_dismiss.concat(
        team_changed_notices.where(team_id: current_teams).ids
      )
    end
  end

  def notice_key(notice)
    [
      notice.patient_id,
      notice.type,
      notice.team_id,
      notice.vaccination_record_id
    ]
  end

  def notice_key_for(patient_id, type, team_id, vaccination_record_id = nil)
    [patient_id, type.to_s, team_id, vaccination_record_id]
  end
end
