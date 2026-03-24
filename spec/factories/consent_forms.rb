# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_forms
#
#  id                                  :bigint           not null, primary key
#  address_line_1                      :string
#  address_line_2                      :string
#  address_postcode                    :string
#  address_town                        :string
#  archived_at                         :datetime
#  confirmation_sent_at                :datetime
#  date_of_birth                       :date
#  education_setting                   :integer
#  ethnic_background                   :integer
#  ethnic_background_other             :string
#  ethnic_group                        :integer
#  family_name                         :text
#  given_name                          :text
#  health_answers                      :jsonb            not null
#  nhs_number                          :string
#  notes                               :text             default(""), not null
#  parent_contact_method_other_details :string
#  parent_contact_method_type          :string
#  parent_email                        :string
#  parent_full_name                    :string
#  parent_phone                        :string
#  parent_phone_receive_updates        :boolean          default(FALSE), not null
#  parent_relationship_other_name      :string
#  parent_relationship_type            :string
#  preferred_family_name               :string
#  preferred_given_name                :string
#  recorded_at                         :datetime
#  school_confirmed                    :boolean
#  use_preferred_name                  :boolean
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  original_session_id                 :bigint
#  school_id                           :bigint
#  team_location_id                    :bigint           not null
#
# Indexes
#
#  index_consent_forms_on_nhs_number                  (nhs_number)
#  index_consent_forms_on_original_session_id         (original_session_id)
#  index_consent_forms_on_recorded                    (id) WHERE (recorded_at IS NOT NULL)
#  index_consent_forms_on_school_id                   (school_id)
#  index_consent_forms_on_team_location_id            (team_location_id)
#  index_consent_forms_on_unmatched_and_not_archived  (id) WHERE ((recorded_at IS NOT NULL) AND (archived_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (original_session_id => sessions.id)
#  fk_rails_...  (school_id => locations.id)
#  fk_rails_...  (team_location_id => team_locations.id)
#

require_relative "../../lib/faker/address"

FactoryBot.define do
  factory :consent_form do
    transient do
      session { association(:session) }

      academic_year { session.academic_year }
      location { session.location }
      programmes { session.programmes }
      team { session.team }

      response { "given" }
      reason_for_refusal { nil }
      reason_for_refusal_notes { "" }
      without_gelatine { false }
      year_group { programmes.flat_map(&:default_year_groups).sort.uniq.first }
    end

    given_name { Faker::Name.first_name }
    family_name { Faker::Name.last_name }
    use_preferred_name { false }
    date_of_birth do
      if year_group
        date_range =
          year_group.to_birth_academic_year(
            academic_year:
          ).to_academic_year_date_range
        Faker::Date.between(from: date_range.begin, to: date_range.end)
      else
        Faker::Date.birthday(min_age: 7, max_age: 16)
      end
    end
    address_line_1 { Faker::Address.street_address }
    address_town { Faker::Address.city }
    address_postcode { Faker::Address.uk_postcode }

    parent_email { Faker::Internet.email }
    parent_full_name { "#{Faker::Name.first_name} #{family_name}" }
    parent_phone { "07700 900#{rand(0..999).to_s.rjust(3, "0")}" }
    parent_phone_receive_updates { parent_phone.present? }

    parent_relationship_type { ParentRelationship.types.keys.sample }
    parent_relationship_other_name do
      parent_relationship_type == "other" ? "Other" : nil
    end

    parent_contact_method_type do
      Parent.contact_method_types.keys.sample if parent_phone.present?
    end
    parent_contact_method_other_details do
      parent_contact_method_type == "other" ? "Other details." : nil
    end

    parental_responsibility { "yes" }

    original_session { session }
    team_location do
      session&.team_location || location.attach_to_team!(team, academic_year:)
    end

    school do
      location.gias_school? ? location : association(:gias_school, team:)
    end
    school_confirmed { true }

    ethnic_group { ConsentForm.ethnic_backgrounds_by_group.keys.sample }

    ethnic_background do
      ConsentForm.ethnic_backgrounds_for_group(ethnic_group).sample
    end

    ethnic_background_other do
      if ConsentForm.any_other_ethnic_backgrounds.include?(ethnic_background)
        "Any other background details"
      end
    end

    health_answers do
      [
        HealthAnswer.new(
          id: 0,
          question: "Is there anything we should know?",
          response: "no"
        )
      ]
    end

    after(:build) do |consent_form, evaluator|
      evaluator.programmes.each do |programme|
        consent_form.consent_form_programmes.build(
          programme:,
          disease_types:
            (
              if programme.mmr?
                programme.variants.sample.disease_types
              else
                Programme::DISEASE_TYPES[programme.type]
              end
            ),
          response: evaluator.response
        )
      end
    end

    trait :archived do
      archived_at { Time.current }
    end

    trait :given do
      response { "given" }
    end

    trait :refused do
      response { "refused" }
      reason_for_refusal { "personal_choice" }
      health_answers { [] }
    end

    trait :education_setting_home do
      education_setting { "home" }
      school { nil }
      school_confirmed { false }
    end

    after(:create) do |consent_form, evaluator|
      vaccine_methods = evaluator.response == "given" ? %w[injection] : []
      without_gelatine = evaluator.without_gelatine

      consent_form.consent_form_programmes.update_all(
        notes: evaluator.reason_for_refusal_notes,
        reason_for_refusal: evaluator.reason_for_refusal,
        response: evaluator.response,
        vaccine_methods:,
        without_gelatine:
      )
    end

    trait :with_health_answers_no_branching do
      health_answers do
        [
          HealthAnswer.new(
            id: 0,
            question:
              "Does the child have any severe allergies that have led to an anaphylactic reaction?",
            next_question: 1,
            response: "no"
          ),
          HealthAnswer.new(
            id: 1,
            question: "Does the child have any existing medical conditions?",
            next_question: 2,
            response: "no"
          ),
          HealthAnswer.new(
            id: 2,
            question: "Does the child take any regular medication?",
            response: "no"
          )
        ]
      end
    end

    trait :with_health_answers_asthma_branching do
      health_answers do
        [
          HealthAnswer.new(
            id: 0,
            question: "Has your child been diagnosed with asthma?",
            next_question: 2,
            follow_up_question: 1,
            response: "yes",
            notes: "Notes",
            would_require_triage: false
          ),
          HealthAnswer.new(
            id: 1,
            question: "Have they taken oral steroids in the last 2 weeks?",
            next_question: 2,
            response: "no"
          ),
          HealthAnswer.new(
            id: 2,
            question:
              "Has your child had a flu vaccination in the last 5 months?",
            response: "no"
          )
        ]
      end
    end

    trait :recorded do
      recorded_at { Time.zone.now }
    end

    trait :draft do
      recorded_at { nil }
    end
  end
end
