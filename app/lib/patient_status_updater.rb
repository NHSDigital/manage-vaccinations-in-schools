# frozen_string_literal: true

##
# This class is used to update the programme and registration statuses of a
#  single or multiple patients.
#
# It works in four stages:
#
# - `Patient::ProgrammeStatus` instances are created for all combinations of
#   patients, programmes and academic years.
# - The `Patient::ProgrammeStatus` objects that were created in the previous
#   step are updated to ensure they reflect the latest status.
# - `Patient::RegistrationStatus` instances are created for all combinations
#   of patients and sessions.
# - The `Patient::RegistrationStatus` objects that were created in the
#   previous step are updated to ensure they reflect the latest status.
class PatientStatusUpdater < PatientScopedUpdater
  def initialize(patient_scope: nil, patient: nil, academic_years: nil)
    super(patient_scope:, patient:)
    @academic_years = academic_years || AcademicYear.all
  end

  def call
    update_programme_statuses!
    update_registration_statuses!
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :patient_scope, :academic_years

  def update_programme_statuses!
    Patient::ProgrammeStatus.import!(
      %i[patient_id programme_type academic_year],
      programme_statuses_to_import,
      on_duplicate_key_ignore: true
    )

    merge_patient_scope(Patient::ProgrammeStatus)
      .where(academic_year: academic_years)
      .in_batches do |relation|
        batch =
          relation.includes(
            :attendance_record,
            :consents,
            :patient,
            :patient_locations,
            :triages,
            :vaccination_records,
            :parents,
            :consent_notifications,
            patient_locations: {
              location: [
                { team_locations: { sessions: :session_programme_year_groups } }
              ]
            }
          ).to_a

        batch.each(&:assign)

        Patient::ProgrammeStatus.import!(
          batch.select(&:changed?),
          on_duplicate_key_update: {
            conflict_target: [:id],
            columns: %i[
              consent_status
              consent_vaccine_methods
              date
              disease_types
              dose_sequence
              location_id
              status
              vaccine_methods
              without_gelatine
            ]
          }
        )
      end
  end

  def update_registration_statuses!
    Patient::RegistrationStatus.import!(
      %i[patient_id session_id],
      patient_location_statuses_to_import,
      on_duplicate_key_ignore: true
    )

    merge_patient_scope(Patient::RegistrationStatus)
      .joins(session: :team_location)
      .where(team_location: { academic_year: academic_years })
      .in_batches do |relation|
        batch =
          relation.includes(
            :attendance_records,
            :patient,
            :session,
            :vaccination_records
          ).to_a

        batch.each(&:assign_status)

        Patient::RegistrationStatus.import!(
          batch.select(&:changed?),
          on_duplicate_key_update: {
            conflict_target: [:id],
            columns: %i[status]
          }
        )
      end
  end

  def programme_statuses_to_import
    @programme_statuses_to_import ||=
      (patient_scope || Patient.all)
        .pluck(:id)
        .flat_map do |patient_id|
          academic_years.flat_map do |academic_year|
            Programme::TYPES.map do |programme_type|
              [patient_id, programme_type, academic_year]
            end
          end
        end
  end

  def patient_location_statuses_to_import
    merge_patient_scope(PatientLocation)
      .joins(:patient)
      .joins_sessions
      .where(team_locations: { academic_year: academic_years })
      .pluck(
        "patients.id",
        "sessions.id",
        "team_locations.academic_year",
        "patients.birth_academic_year"
      )
      .filter_map do |patient_id, session_id, academic_year, birth_academic_year|
        year_group = birth_academic_year.to_year_group(academic_year:)

        if programme_types_per_session_id_and_year_group
             .fetch(session_id, {})
             .fetch(year_group, [])
             .empty?
          next
        end

        [patient_id, session_id]
      end
  end

  def programme_types_per_session_id_and_year_group
    @programme_types_per_session_id_and_year_group ||=
      Session::ProgrammeYearGroup
        .joins(session: :team_location)
        .where(team_location: { academic_year: academic_years })
        .pluck(:session_id, :programme_type, :year_group)
        .each_with_object(
          {}
        ) do |(session_id, programme_type, year_group), hash|
          hash[session_id] ||= {}
          hash[session_id][year_group] ||= []
          hash[session_id][year_group] << programme_type
        end
  end

  # We preload this association separately because including it in the nested
  # `patient_locations` preload (see includes above) caused the updater process
  # to be killed, even with very small batches. The likely cause is memory pressure
  # from eager loading a deeply nested association graph.
  #
  # Preloading it here for the distinct `Location` records in each batch keeps
  # `StatusGenerator::Programme` query-free without incurring the cost of the
  # larger nested preload.
  def preload_location_programme_year_groups(batch)
    locations = batch.flat_map(&:patient_locations).map(&:location).uniq

    ActiveRecord::Associations::Preloader.new(
      records: locations,
      associations: {
        location_programme_year_groups: :location_year_group
      }
    ).call
  end
end
