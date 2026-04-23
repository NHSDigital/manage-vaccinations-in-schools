# frozen_string_literal: true

# == Schema Information
#
# Table name: notes
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  created_by_user_id :bigint           not null
#  patient_id         :bigint           not null
#  session_id         :bigint
#
# Indexes
#
#  index_notes_on_created_by_user_id  (created_by_user_id)
#  index_notes_on_patient_id          (patient_id)
#  index_notes_on_session_id          (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_user_id => users.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (session_id => sessions.id)
#
FactoryBot.define do
  factory :note do
    created_by
    patient
    session { patient.sessions.first || association(:session) }

    body { Faker::Lorem.sentence }
  end
end
