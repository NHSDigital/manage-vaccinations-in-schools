# frozen_string_literal: true

module PatientImportConcern
  extend ActiveSupport::Concern

  def import_patients_and_parents(changesets, import)
    patients = changesets.map(&:patient)
    parents = changesets.flat_map(&:parents).uniq
    relationships =
      changesets
        .flat_map(&:parent_relationships)
        .uniq { [_1.parent, _1.patient] }

    deduplicate_patients!(patients, relationships)

    patients_with_nhs_number_changes =
      patients.select(&:nhs_number_previously_changed?)

    Patient.import(patients.to_a, on_duplicate_key_update: :all)
    link_records_to_import(import, Patient, patients)

    SearchVaccinationRecordsInNHSJob.perform_bulk(
      patients_with_nhs_number_changes.pluck(:id).zip
    )

    changesets.each(&:assign_patient_id)
    PatientChangeset.import(changesets, on_duplicate_key_update: :all)

    Parent.import(parents.to_a, on_duplicate_key_update: :all)
    link_records_to_import(import, Parent, parents)

    ParentRelationship.import(
      relationships.to_a,
      on_duplicate_key_update: {
        conflict_target: %i[parent_id patient_id],
        columns: %i[type other_name]
      }
    )
    link_records_to_import(import, ParentRelationship, relationships)
  end

  def deduplicate_patients!(patients, relationships)
    @patients_by_nhs_number ||= {}

    patients.reject! do |patient|
      next false if patient.nhs_number.blank?

      existing_patient = @patients_by_nhs_number[patient.nhs_number]
      if patient.persisted? || existing_patient.nil?
        @patients_by_nhs_number[patient.nhs_number] = patient
        next false
      else
        relationships
          .select { _1.patient == patient }
          .each { _1.patient = existing_patient }
        next true
      end
    end
    patients.uniq!
  end

  def import_school_moves(changesets, import)
    school_moves = changesets.map(&:school_move).compact.uniq(&:patient)

    auto_confirmable_school_moves, importable_school_moves =
      school_moves.partition { has_auto_confirmable_school_move?(it, import) }

    auto_confirmable_school_moves.each do |school_move|
      # if the same patient appears multiple times in the file,
      # the duplicates won't be persisted, so we can skip those
      school_move.confirm! if school_move.patient.persisted?
    end

    school_move_import_records = importable_school_moves.to_a

    SchoolMove.import!(
      school_move_import_records,
      on_duplicate_key_update: :all
    )
  end

  def import_pds_search_results(changesets, import)
    pds_search_records = []

    changesets.each do |changeset|
      next if changeset.search_results.blank?

      patient = changeset.patient
      next unless patient.persisted?

      changeset.search_results.each do |result|
        pds_search_records << PDSSearchResult.new(
          patient_id: patient.id,
          step: PDSSearchResult.steps[result["step"]],
          result: PDSSearchResult.results[result["result"]],
          nhs_number: result["nhs_number"],
          import:,
          created_at: result["created_at"]
        )
      end
    end

    PDSSearchResult.import(pds_search_records, on_duplicate_key_ignore: true)
  end

  def link_records_to_import(import_source, record_class, records)
    source_type = import_source.class.name
    record_type = record_class.name

    join_table_class = "#{source_type.pluralize}#{record_type}".constantize
    join_table_class.import(
      ["#{source_type.underscore}_id", "#{record_type.underscore}_id"],
      records.map { [import_source.id, it.id] },
      on_duplicate_key_ignore: true
    )
  end

  def increment_column_counts!(import, counts, changesets)
    changesets.each do |changeset|
      count_column_to_increment =
        import.count_column(
          changeset.patient,
          changeset.parents.uniq,
          changeset.parent_relationships.uniq
        )
      counts[count_column_to_increment] += 1
    end
  end

  def has_auto_confirmable_school_move?(school_move, import)
    return false if school_move.from_another_team?

    patient = school_move.patient
    team = import.team

    patient_has_no_education_location_yet?(patient:) ||
      patient_archived_and_not_in_another_team?(patient:, team:) ||
      school_move_does_not_move_patient?(school_move:, patient:)
  end

  private

  def patient_has_no_education_location_yet?(patient:)
    patient.school_id.nil? || patient.school.urn == Location::URN_UNKNOWN
  end

  def school_move_does_not_move_patient?(school_move:, patient:)
    school_move.school == patient.school
  end

  def patient_archived_and_not_in_another_team?(patient:, team:)
    patient.archived?(team:) && patient.teams.where.not(id: team.id).empty?
  end

  def reset_counts(import)
    cached_counts = TeamCachedCounts.new(import.team)
    cached_counts.reset_import_issues!
    cached_counts.reset_school_moves!
  end
end
