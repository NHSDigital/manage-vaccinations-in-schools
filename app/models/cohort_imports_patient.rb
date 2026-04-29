# frozen_string_literal: true

# == Schema Information
#
# Table name: cohort_imports_patients
#
#  cohort_import_id :bigint           not null
#  patient_id       :bigint           not null
#
# Indexes
#
#  idx_on_cohort_import_id_patient_id_7864d1a8b0  (cohort_import_id,patient_id) UNIQUE
#  idx_on_patient_id_cohort_import_id_5e41b290b4  (patient_id,cohort_import_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cohort_import_id => cohort_imports.id) ON DELETE => cascade
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
class CohortImportsPatient < ApplicationRecord
  belongs_to :cohort_import
  belongs_to :patient
end
