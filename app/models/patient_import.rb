# frozen_string_literal: true

class PatientImport < ApplicationRecord
  include Importable

  PDS_MATCH_THRESHOLD = 0.7
  CHANGESET_THRESHOLD = 10

  self.abstract_class = true

  has_many :patient_changesets

  def count_column(patient, parents, parent_relationships)
    if patient.new_record? || parents.any?(&:new_record?) ||
         parent_relationships.any?(&:new_record?)
      :new_record_count
    elsif patient.changed? || parents.any?(&:changed?) ||
          parent_relationships.any?(&:changed?)
      :changed_record_count
    else
      :exact_duplicate_record_count
    end
  end

  def show_approved_reviewers?
    (processed? || partially_processed?) && reviewed_by_user_ids.present?
  end

  def show_cancelled_reviewer?
    (cancelled? || partially_processed?) && reviewed_by_user_ids.present?
  end

  def records_count
    changesets.from_file.count
  end

  def process!
    raise "'rows' are empty. Call parse_rows! before processing." if rows.nil?

    changesets =
      rows.each_with_index.map do |row, row_number|
        PatientChangeset.from_import_row(row:, import: self, row_number:)
      end

    if Flipper.enabled?(:pds) && Flipper.enabled?(:pds_search_during_import)
      process_no_postcode_changesets(self.changesets.without_postcode)
      if self.changesets.with_postcode.any?
        enqueue_pds_cascading_searches(self.changesets.with_postcode)
        return
      end
    end

    changesets.each(&:assign_patient_id)

    validate_changeset_uniqueness!
    return if changesets_are_invalid?

    enqueue_review_jobs(self.changesets)

    TeamCachedCounts.new(team).reset_import_issues!
  end

  def validate_pds_match_rate!
    return if valid_pds_match_rate? || changesets.count < CHANGESET_THRESHOLD

    update!(status: :low_pds_match_rate)
    changesets.update_all(status: :import_invalid)
  end

  def pds_match_rate
    return 0 if changesets.with_pds_match.count.zero?

    matched = changesets.with_pds_match.count.to_f
    attempted = changesets.with_pds_search_attempted.count

    (matched / attempted * 100).round(2)
  end

  def validate_changeset_uniqueness!
    row_errors = {}

    nhs_duplicates =
      changesets
        .group_by(&:nhs_number)
        .select { |nhs, cs| nhs.present? && cs.size > 1 }

    nhs_duplicates.each do |nhs_number, changesets|
      changesets.each do |cs|
        other_rows_text = generate_other_rows_text(cs, changesets)
        row_errors["Row #{cs.csv_row_number}"] ||= [[]]
        row_errors["Row #{cs.csv_row_number}"][
          0
        ] << "The details on this row match #{other_rows_text}. " \
          "Mavis has found the NHS number #{nhs_number}."
      end
    end

    patient_duplicates =
      changesets
        .group_by(&:patient_id)
        .select { |pid, cs| pid.present? && cs.size > 1 }

    patient_duplicates.each_value do |changesets|
      changesets.each do |cs|
        other_rows_text = generate_other_rows_text(cs, changesets)
        row_errors["Row #{cs.csv_row_number}"] ||= [[]]
        row_errors["Row #{cs.csv_row_number}"][
          0
        ] << "The record on this row appears to be a duplicate of #{other_rows_text}."
      end
    end

    if row_errors.any?
      update!(status: :changesets_are_invalid)
      update!(serialized_errors: row_errors)
      changesets.update_all(status: :import_invalid)
    end
  end

  def commit_changesets(changesets)
    changesets_ids = changesets.ids

    changesets.update_all(status: :committing)
    changesets_ids.each_slice(100) do |batch_ids|
      CommitPatientChangesetsJob.perform_async(batch_ids)
    end
  end

  def remaining_parent_relationships(remove_option:)
    if remove_option == "unconsented_only"
      parent_relationships -
        parent_relationship_consents.map(&:parent_relationship)
    else
      parent_relationships
    end
  end

  def parent_relationship_consents(scope: parent_relationships)
    Consent
      .includes(patient: { parent_relationships: :parent })
      .joins(patient: :parent_relationships)
      .merge(patients)
      .merge(scope)
      .where("consents.parent_id = parent_relationships.parent_id")
      .not_invalidated
  end

  private

  def process_no_postcode_changesets(changesets)
    changesets.find_each do |cs|
      cs.search_results << {
        step: :no_fuzzy_with_history,
        result: :no_postcode,
        nhs_number: nil,
        created_at: Time.current
      }
      cs.calculating_review!
      ReviewPatientChangesetJob.perform_later(cs.id)
    end
  end

  def enqueue_review_jobs(changesets)
    review_changesets =
      if Flipper.enabled?(:pds) && Flipper.enabled?(:pds_search_during_import)
        changesets.with_postcode
      else
        changesets
      end

    review_changesets.each do |cs|
      cs.calculating_review!
      ReviewPatientChangesetJob.perform_later(cs.id)
    end
  end

  def enqueue_pds_cascading_searches(changesets)
    changesets.find_each do |cs|
      PDSCascadingSearchJob.set(queue: :imports).perform_later(
        cs,
        queue: :imports
      )
    end
  end

  def valid_pds_match_rate?
    pds_match_rate / 100 >= PDS_MATCH_THRESHOLD
  end

  def generate_other_rows_text(current_row, duplicate_rows, count = 5)
    current_row_index =
      duplicate_rows.index { it.row_number == current_row.row_number }
    start_row = [current_row_index - count, 0].max
    other_rows = duplicate_rows[start_row, count + 1] - [current_row]
    other_row_numbers = other_rows.map(&:csv_row_number)

    "#{"row".pluralize(other_row_numbers.size)} #{other_row_numbers.to_sentence(last_word_connector: " and ")}"
  end
end
