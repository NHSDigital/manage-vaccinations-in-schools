# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_change_log_entries
#
#  id                :bigint           not null, primary key
#  recorded_changes  :jsonb            not null
#  source            :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  patient_id        :bigint           not null
#  user_id           :bigint
#
# Indexes
#
#  index_patient_change_log_entries_on_patient_id  (patient_id)
#  index_patient_change_log_entries_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (user_id => users.id)
#
class PatientChangeLogEntry < ApplicationRecord
  TRACKED_ATTRIBUTES = %w[
    given_name
    family_name
    preferred_given_name
    preferred_family_name
    date_of_birth
    gender_code
    nhs_number
    address_line_1
    address_line_2
    address_town
    address_postcode
  ].freeze

  belongs_to :patient
  belongs_to :user, optional: true

  enum :source, { manual_edit: 0, cohort_import: 1, class_import: 2 }

  def self.log_saved_changes!(patient:, user:, source:)
    recorded_changes = patient.saved_changes.slice(*TRACKED_ATTRIBUTES)
    return if recorded_changes.empty?

    create!(patient:, user:, source:, recorded_changes:)
  end

  def self.log_import_changes!(patients:, import:)
    source = import.is_a?(CohortImport) ? :cohort_import : :class_import
    user = import.uploaded_by

    patients.each do |patient|
      next if patient.id.blank?

      recorded_changes = patient.changes.slice(*TRACKED_ATTRIBUTES)
      next if recorded_changes.empty?

      create!(patient:, user:, source:, recorded_changes:)
    end
  end
end
