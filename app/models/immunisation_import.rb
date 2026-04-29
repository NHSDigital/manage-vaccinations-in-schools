# frozen_string_literal: true

# == Schema Information
#
# Table name: immunisation_imports
#
#  id                           :bigint           not null, primary key
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text             not null
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  ignored_record_count         :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  type                         :integer          not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_immunisation_imports_on_team_id              (team_id)
#  index_immunisation_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
class ImmunisationImport < ApplicationRecord
  include CSVImportable
  include Importable

  self.inheritance_column = nil

  enum :type, { point_of_care: 0, national_reporting: 1 }, validate: true

  has_and_belongs_to_many :patient_locations
  has_and_belongs_to_many :sessions
  has_and_belongs_to_many :vaccination_records

  def type_label
    "Vaccination records"
  end

  def show_approved_reviewers?
    false
  end

  def show_cancelled_reviewer?
    false
  end

  def records_count
    if national_reporting?
      vaccination_records.count + (ignored_record_count || 0)
    else
      vaccination_records.count
    end
  end

  def process!
    raise "'rows' are empty. Call parse_rows! before processing." if rows.nil?

    counts = count_columns.index_with(0)

    @vaccination_records_batch = Set.new
    @patients_batch = Set.new
    @patient_locations_batch = Set.new
    @archive_reasons_batch = Set.new

    ActiveRecord::Base.transaction do
      rows.each do |row|
        count_column_to_increment = process_row(row)
        counts[count_column_to_increment] += 1
        bulk_import(rows: 100)
      end

      bulk_import(rows: :all)

      postprocess_rows!
    end

    post_commit!

    update_columns(processed_at: Time.zone.now, status: :processed, **counts)
  end

  private

  def parse_row(data)
    ImmunisationImportRow.new(data:, team:, type:)
  end

  def process_row(row)
    patient = row.set_patient(candidates: @patients_batch)
    vaccination_record = row.to_vaccination_record

    count_column_to_increment = count_column(vaccination_record)
    return count_column_to_increment unless vaccination_record

    @vaccination_records_batch.add(vaccination_record)
    @patients_batch.add(patient)

    if (patient_location = row.to_patient_location)
      @patient_locations_batch.add(patient_location)
    end

    if (archive_reason = row.to_archive_reason)
      @archive_reasons_batch.add(archive_reason)
    end

    count_column_to_increment
  end

  def bulk_import(rows: 100)
    return if rows != :all && @vaccination_records_batch.size < rows

    # We need to convert the batch to an array as `import` modifies the
    # objects to add IDs to any new records.
    patients = @patients_batch.to_a
    vaccination_records = @vaccination_records_batch.to_a
    patient_locations = @patient_locations_batch.to_a
    archive_reasons = @archive_reasons_batch.to_a

    Patient.import!(patients, on_duplicate_key_update: :all)

    VaccinationRecord.import!(
      vaccination_records,
      on_duplicate_key_update: :all
    )

    PatientLocation.import(patient_locations, on_duplicate_key_ignore: :all)

    ArchiveReason.import(archive_reasons)

    Imports::JoinRecords.call(self, vaccination_records)
    Imports::JoinRecords.call(self, patients)
    Imports::JoinRecords.call(self, patient_locations.select { it.id.present? })

    @patients_batch.clear
    @vaccination_records_batch.clear
    @patient_locations_batch.clear
    @archive_reasons_batch.clear
  end

  def count_columns
    super + %i[ignored_record_count]
  end

  def count_column(vaccination_record)
    if vaccination_record.nil?
      :ignored_record_count
    elsif vaccination_record.new_record?
      :new_record_count
    elsif vaccination_record.pending_changes.any? ||
          vaccination_record.patient.pending_changes.any?
      :changed_record_count
    else
      :exact_duplicate_record_count
    end
  end

  def postprocess_rows!
    vaccination_records
      .includes(:patient, :team)
      .find_each do |vaccination_record|
        NextDoseTriageFactory.call(vaccination_record:)
      end
  end

  def post_commit!
    PatientTeamUpdater.call(patient_scope: patients)
    PatientStatusUpdater.call(patient_scope: Patient.where(id: patients.ids))

    vaccination_records.sync_all_to_nhs_immunisations_api

    vaccination_records
      .includes(:patient, :team, :subteam)
      .find_each do |vaccination_record|
        AlreadyHadNotificationSender.call(vaccination_record:)
      end

    UpdatePatientsFromPDS.call(patients, queue: :imports)

    TeamCachedCounts.new(team).reset_import_issues!
  end
end
