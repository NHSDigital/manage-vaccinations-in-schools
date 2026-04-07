# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id                              :bigint           not null, primary key
#  careplus_password               :string
#  careplus_staff_code             :string
#  careplus_staff_type             :string
#  careplus_username               :string
#  careplus_venue_code             :string
#  days_before_consent_reminders   :integer          default(7), not null
#  days_before_consent_requests    :integer          default(21), not null
#  email                           :string
#  name                            :text             not null
#  national_reporting_cut_off_date :date
#  phone                           :string
#  phone_instructions              :string
#  privacy_notice_url              :string
#  privacy_policy_url              :string
#  programme_types                 :enum             not null, is an Array
#  type                            :integer          not null
#  workgroup                       :string           not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  organisation_id                 :bigint           not null
#  reply_to_id                     :uuid
#
# Indexes
#
#  index_teams_on_name             (name) UNIQUE
#  index_teams_on_organisation_id  (organisation_id)
#  index_teams_on_programme_types  (programme_types) USING gin
#  index_teams_on_workgroup        (workgroup) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organisation_id => organisations.id)
#
FactoryBot.define do
  factory :team do
    transient do
      sequence(:identifier)
      ods_code { generate(:ods_code) }
      programmes { [] }
    end

    organisation { association(:organisation, ods_code:) }
    programme_types { programmes.map(&:type) }

    workgroup { "w#{identifier}" }
    name { "SAIS Team #{identifier}" }

    email { "sais-team-#{identifier}@example.com" }
    phone { "01234 567890" }
    privacy_notice_url { "https://example.com/privacy-notice" }
    privacy_policy_url { "https://example.com/privacy-policy" }

    type { :point_of_care }

    trait :national_reporting do
      type { :national_reporting }

      email { nil }
      phone { nil }
      privacy_notice_url { nil }
      privacy_policy_url { nil }

      programmes { [Programme.flu, Programme.hpv] }
    end

    trait :support do
      type { :support }

      email { nil }
      phone { nil }
      privacy_notice_url { nil }
      privacy_policy_url { nil }
    end

    trait :with_one_nurse do
      users { [create(:user, :nurse, team: instance)] }
    end

    trait :with_one_admin do
      users { [create(:user, :medical_secretary, team: instance)] }
    end

    trait :with_one_healthcare_assistant do
      users { [create(:user, :healthcare_assistant, team: instance)] }
    end

    trait :with_careplus_enabled do
      careplus_staff_code { "LW5PM" }
      careplus_staff_type { "IN" }
      careplus_venue_code { identifier.to_s }
      careplus_username { "careplus_user" }
      careplus_password { "careplus_password" }
    end

    after(:create) do |team|
      GenericLocationFactory.call(team:, academic_year: AcademicYear.pending)
    end
  end
end
