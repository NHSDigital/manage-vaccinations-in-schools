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
FactoryBot.define do
  factory :patient_change_log_entry do
    patient
    user
    source { :manual_edit }
    recorded_changes { { "given_name" => %w[Old New] } }
  end
end
