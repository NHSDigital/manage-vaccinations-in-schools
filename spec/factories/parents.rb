# frozen_string_literal: true

# == Schema Information
#
# Table name: parents
#
#  id                           :bigint           not null, primary key
#  contact_method_other_details :text
#  contact_method_type          :string
#  email                        :string
#  full_name                    :string
#  other_name                   :string
#  phone                        :string
#  phone_receive_updates        :boolean          default(FALSE), not null
#  type                         :enum
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  patient_id                   :bigint
#
# Indexes
#
#  index_parents_on_email       (email)
#  index_parents_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#
FactoryBot.define do
  factory :parent do
    transient do
      given_name { Faker::Name.first_name }
      family_name { Faker::Name.last_name }
    end

    full_name { "#{given_name} #{family_name}" }
    email { Faker::Internet.email }
    phone { "07700 900#{rand(0..999).to_s.rjust(3, "0")}" }
    phone_receive_updates { phone.present? }
    type { %w[father guardian mother other].sample }
    other_name { type == "other" ? "Other" : nil }

    trait :non_contactable do
      phone { nil }
      email { nil }
    end

    trait :contact_method_any do
      contact_method_type { "any" }
    end

    trait :contact_method_text do
      contact_method_type { "text" }
    end

    trait :contact_method_voice do
      contact_method_type { "voice" }
    end

    trait :contact_method_other do
      contact_method_type { "other" }
      contact_method_other_details { "Other details." }
    end
  end
end
