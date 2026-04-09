# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    transient do
      given_name { Faker::Name.first_name }
      family_name { Faker::Name.last_name }
    end

    full_name { "#{given_name} #{family_name}" }
    relationship { "mother" }
    source { "consent_response" }

    trait :phone do
      contact_method { "phone" }
      phone { "07700 900#{rand(0..999).to_s.rjust(3, "0")}" }
      phone_receive_updates { true }
    end

    trait :email do
      contact_method { "email" }
      email { Faker::Internet.email }
    end
  end
end
