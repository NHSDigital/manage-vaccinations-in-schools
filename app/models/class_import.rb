# frozen_string_literal: true

# == Schema Information
#
# Table name: class_imports
#
#  id                           :bigint           not null, primary key
#  academic_year                :integer          not null
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  reviewed_at                  :datetime         default([]), not null, is an Array
#  reviewed_by_user_ids         :bigint           default([]), not null, is an Array
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  year_groups                  :integer          default([]), not null, is an Array
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  location_id                  :bigint           not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_class_imports_on_location_id          (location_id)
#  index_class_imports_on_team_id              (team_id)
#  index_class_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
class ClassImport < PatientImport
  include CSVImportable

  belongs_to :location

  has_and_belongs_to_many :parent_relationships
  has_and_belongs_to_many :parents
  has_many :changesets,
           class_name: "PatientChangeset",
           as: :import,
           dependent: :destroy
  has_many :pds_search_results

  def type_label
    "Class list records"
  end

  def postprocess_rows!
    # Remove patients already in the sessions but not in the class list.
    patients_in_import_changesets =
      changesets.from_file.where.not(status: %i[cancelled processed])

    patients_in_import =
      Patient.joins(:changesets).merge(patients_in_import_changesets)

    unknown_patients = patients_to_create_moves_for(patients_in_import)

    valid_changesets =
      changesets.not_from_file.committing.where(
        patient_id: unknown_patients.pluck(:id)
      )
    valid_patients = Patient.joins(:changesets).merge(valid_changesets)

    changesets
      .not_from_file
      .committing
      .where.not(id: valid_changesets.ids)
      .destroy_all

    missed_patients = unknown_patients - valid_patients
    if missed_patients.any? && (processed? || partially_processed?)
      update_columns(status: :calculating_re_review, processed_at: nil)
      ReviewClassImportSchoolMoveJob.perform_later(id)
    end

    unknown_patients = valid_patients

    school_moves =
      unknown_patients.map do |patient|
        SchoolMove.new(
          academic_year:,
          school: team.unknown_school,
          patient:,
          source: "class_list_import"
        )
      end

    SchoolMove.import!(school_moves, on_duplicate_key_ignore: true)

    valid_changesets.update_all(status: :processed) if valid_changesets

    PatientsAgedOutOfSchoolJob.perform_async(location_id)
  end

  def post_commit!
  end

  def patients_to_create_moves_for(patients_in_import)
    birth_academic_years =
      year_groups.map { it.to_birth_academic_year(academic_year:) }

    existing_patients =
      Patient.where(
        birth_academic_year: birth_academic_years,
        school: location
      ).where(
        PatientLocation
          .joins(:school)
          .where("patient_id = patients.id")
          .where(academic_year:, school: location)
          .arel
          .exists
      )

    patients_not_in_import = existing_patients - patients_in_import - patients

    # We do not update existing school moves
    patients_with_school_moves =
      Patient
        .joins(:school_moves)
        .where(id: patients_not_in_import.pluck(:id))
        .where(school_moves: { academic_year: })

    patients_not_in_import - patients_with_school_moves
  end

  private

  def parse_row(data)
    ClassImportRow.new(data:, team:, academic_year:, location:, year_groups:)
  end
end
