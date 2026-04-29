# frozen_string_literal: true

# == Schema Information
#
# Table name: class_imports_patients
#
#  class_import_id :bigint           not null
#  patient_id      :bigint           not null
#
# Indexes
#
#  index_class_imports_patients_on_class_import_id_and_patient_id  (class_import_id,patient_id) UNIQUE
#  index_class_imports_patients_on_patient_id_and_class_import_id  (patient_id,class_import_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (class_import_id => class_imports.id) ON DELETE => cascade
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
class ClassImportsPatient < ApplicationRecord
  belongs_to :class_import
  belongs_to :patient
end
