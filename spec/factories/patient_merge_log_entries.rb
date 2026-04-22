# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_merge_log_entries
#
#  id                        :bigint           not null, primary key
#  merged_patient_dob        :date             not null
#  merged_patient_name       :string           not null
#  merged_patient_nhs_number :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  merged_patient_id         :bigint           not null
#  patient_id                :bigint           not null
#  user_id                   :bigint
#
# Indexes
#
#  index_patient_merge_log_entries_on_patient_id  (patient_id)
#  index_patient_merge_log_entries_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :patient_merge_log_entry do
    patient
    user
    merged_patient_id { rand(100..1000) }
    merged_patient_name { patient.full_name }
    merged_patient_dob { patient.date_of_birth }
    merged_patient_nhs_number { patient.nhs_number || "9999075320" }
  end
end
