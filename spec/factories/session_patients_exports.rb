# frozen_string_literal: true

# == Schema Information
#
# Table name: session_patients_exports
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  session_id :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (session_id => sessions.id)
#
FactoryBot.define do
  factory :session_patients_export do
    session
  end
end
