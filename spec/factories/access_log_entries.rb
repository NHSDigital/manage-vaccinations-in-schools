# frozen_string_literal: true

# == Schema Information
#
# Table name: access_log_entries
#
#  id              :bigint           not null, primary key
#  action          :integer          not null
#  controller      :integer          not null
#  request_details :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  patient_id      :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_access_log_entries_on_patient_id  (patient_id)
#  index_access_log_entries_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :access_log_entry do
    patient
    user

    controller { %w[patients patient_sessions].sample }
    action { %w[show log].sample }
  end
end
