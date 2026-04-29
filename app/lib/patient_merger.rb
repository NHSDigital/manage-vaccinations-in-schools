# frozen_string_literal: true

class PatientMerger
  def initialize(to_keep:, to_destroy:, user: nil)
    @patient_to_keep = to_keep
    @patient_to_destroy = to_destroy
    @user = user
  end

  def call
    vaccination_record_ids = []

    ActiveRecord::Base.transaction do
      patient_to_destroy.access_log_entries.update_all(
        patient_id: patient_to_keep.id
      )

      handle_archive_reasons(patient_to_keep, patient_to_destroy)

      patient_to_destroy.important_notices.destroy_all

      patient_to_destroy.attendance_records.find_each do |attendance_record|
        if patient_to_keep.attendance_records.exists?(
             location_id: attendance_record.location_id,
             date: attendance_record.date
           )
          attendance_record.destroy!
        else
          attendance_record.update_column(:patient_id, patient_to_keep.id)
        end
      end

      patient_to_destroy.consent_notifications.update_all(
        patient_id: patient_to_keep.id
      )
      patient_to_destroy.consents.update_all(patient_id: patient_to_keep.id)

      patient_to_destroy.clinic_notifications.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.notes.update_all(patient_id: patient_to_keep.id)

      patient_to_destroy.notify_log_entries.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.gillick_assessments.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.patient_merge_log_entries.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.patient_specific_directions.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.pds_search_results.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.pre_screenings.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.school_moves.find_each do |school_move|
        if patient_to_keep.school_moves.exists?
          school_move.destroy!
        else
          school_move.update_column(:patient_id, patient_to_keep.id)
        end
      end

      patient_to_destroy.school_move_log_entries.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.session_notifications.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.triages.update_all(patient_id: patient_to_keep.id)

      vaccination_record_ids =
        patient_to_destroy.vaccination_records.with_discarded.ids
      patient_to_destroy.vaccination_records.with_discarded.update_all(
        patient_id: patient_to_keep.id
      )

      patient_to_destroy.parent_relationships.find_each do |relationship|
        if patient_to_keep.parent_relationships.exists?(
             parent_id: relationship.parent_id
           )
          relationship.destroy!
        else
          relationship.update_column(:patient_id, patient_to_keep.id)
        end
      end

      patient_to_destroy.patient_locations.each do |patient_location|
        if patient_to_keep.patient_locations.exists?(
             academic_year: patient_location.academic_year,
             location_id: patient_location.location_id
           )
          next
        end
        patient_location.update_column(:patient_id, patient_to_keep.id)
      end

      PatientLocation.where(patient: patient_to_destroy).destroy_all

      patient_to_destroy
        .patient_programme_vaccinations_searches
        .find_each do |search|
        existing_search =
          patient_to_keep.patient_programme_vaccinations_searches.find_by(
            programme_type: search.programme_type
          )

        if existing_search
          if existing_search.last_searched_at > search.last_searched_at
            search.last_searched_at = existing_search.last_searched_at
          end
          existing_search.destroy!
        end
        search.update!(patient_id: patient_to_keep.id)
      end

      patient_to_destroy.changesets.update_all(patient_id: nil)

      patient_to_destroy.class_imports.each do |import|
        unless patient_to_keep.class_imports.include?(import)
          patient_to_keep.class_imports << import
        end
      end

      patient_to_destroy.cohort_imports.each do |import|
        unless patient_to_keep.cohort_imports.include?(import)
          patient_to_keep.cohort_imports << import
        end
      end

      patient_to_destroy.immunisation_imports.each do |import|
        unless patient_to_keep.immunisation_imports.include?(import)
          patient_to_keep.immunisation_imports << import
        end
      end

      patient_to_destroy.class_imports.clear
      patient_to_destroy.cohort_imports.clear
      patient_to_destroy.immunisation_imports.clear

      patient_to_destroy.patient_teams.find_each do |patient_team_to_destroy|
        patient_team_to_keep =
          patient_to_keep.patient_teams.find_or_initialize_by(
            team_id: patient_team_to_destroy.team_id
          )

        patient_team_to_keep.sources =
          (
            patient_team_to_keep.sources + patient_team_to_destroy.sources
          ).uniq.sort

        patient_team_to_keep.save!
      end

      PatientMergeLogEntry.create!(
        patient: patient_to_keep,
        merged_patient_id: patient_to_destroy.id,
        merged_patient_name: patient_to_destroy.full_name,
        merged_patient_dob: patient_to_destroy.date_of_birth,
        merged_patient_nhs_number: patient_to_keep.nhs_number,
        user: @user
      )

      patient_to_destroy.reload.destroy!

      PatientStatusUpdater.call(patient: patient_to_keep)
    end

    SearchVaccinationRecordsInNHSJob.perform_async(patient_to_keep.id)

    VaccinationRecord.where(
      id: vaccination_record_ids
    ).sync_all_to_nhs_immunisations_api
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  def handle_archive_reasons(patient_to_keep, patient_to_destroy)
    unless patient_to_keep.archive_reasons.exists? ||
             patient_to_destroy.archive_reasons.exists?
      return
    end

    teams = (patient_to_keep.teams + patient_to_destroy.teams).uniq

    teams.each do |team|
      if patient_to_keep.archived?(team_id: team.id) &&
           patient_to_destroy.archived?(team_id: team.id)
        next
      end
      # If one is archived and the other is not, unarchive both
      patient_to_keep
        .archive_reasons
        .not_unarchived
        .where(team:)
        .update_all(
          unarchived_at: Time.current,
          unarchive_reason: :patient_merge,
          unarchived_by_user_id: @user&.id
        )
      patient_to_destroy
        .archive_reasons
        .not_unarchived
        .where(team:)
        .update_all(
          unarchived_at: Time.current,
          unarchive_reason: :patient_merge,
          unarchived_by_user_id: @user&.id
        )
    end

    patient_to_destroy.archive_reasons.update_all(
      patient_id: patient_to_keep.id
    )
  end

  attr_reader :patient_to_keep, :patient_to_destroy
end
