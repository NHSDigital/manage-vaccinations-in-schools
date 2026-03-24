# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id                        :bigint           not null, primary key
#  address_line_1            :text
#  address_line_2            :text
#  address_postcode          :text
#  address_town              :text
#  gias_establishment_number :integer
#  gias_local_authority_code :integer
#  gias_phase                :integer
#  gias_year_groups          :integer          default([]), not null, is an Array
#  name                      :text             not null
#  ods_code                  :string
#  site                      :string
#  status                    :integer          default("unknown"), not null
#  systm_one_code            :string
#  type                      :integer          not null
#  url                       :text
#  urn                       :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_locations_on_ods_code        (ods_code) UNIQUE
#  index_locations_on_systm_one_code  (systm_one_code) UNIQUE
#  index_locations_on_urn             (urn) UNIQUE WHERE ((type = 0) AND (site IS NULL))
#  index_locations_on_urn_and_site    (urn,site) UNIQUE
#

require_relative "../../lib/faker/address"

FactoryBot.define do
  factory :location do
    transient do
      subteam { nil }

      team { subteam&.team }
      programmes { team&.programmes || [] }
      academic_year { AcademicYear.pending }
    end

    url { Faker::Internet.url }

    traits_for_enum :status

    trait :with_address do
      address_line_1 { Faker::Address.street_address }
      address_town { Faker::Address.city }
      address_postcode { Faker::Address.uk_postcode }
    end

    factory :community_clinic do
      type { :community_clinic }
      name { "#{Faker::University.name} Clinic" }
      with_address

      sequence(:ods_code, 100) { "CL#{it}" }

      after(:create) do |location, evaluator|
        if (team = evaluator.team)
          academic_year = evaluator.academic_year
          subteam = evaluator.subteam

          team.team_locations.create!(location:, academic_year:, subteam:)
        end
      end
    end

    factory :generic_clinic do
      type { "generic_clinic" }
      name { "Community clinic" }

      after(:create) do |location, evaluator|
        academic_year = evaluator.academic_year
        subteam = evaluator.subteam

        if (team = evaluator.team)
          team.team_locations.create!(location:, academic_year:, subteam:)
        end

        year_groups = Location::YearGroup::DEFAULT_VALUE_RANGE.to_a

        location.import_year_groups!(
          year_groups,
          academic_year:,
          source: "generic_location_factory"
        )
        location.import_default_programme_year_groups!(
          evaluator.programmes,
          academic_year:
        )
      end
    end

    factory :generic_school do
      type { "generic_school" }
      gias_phase { "not_applicable" }

      trait :unknown do
        name { "Unknown school" }
        urn { Location::URN_UNKNOWN }
      end

      trait :home_educated do
        name { "Home-educated" }
        urn { Location::URN_HOME_EDUCATED }
      end

      after(:create) do |location, evaluator|
        academic_year = evaluator.academic_year
        subteam = evaluator.subteam

        if (team = evaluator.team)
          team.team_locations.create!(location:, academic_year:, subteam:)
        end

        year_groups = Location::YearGroup::DEFAULT_VALUE_RANGE.to_a

        location.import_year_groups!(
          year_groups,
          academic_year:,
          source: "generic_location_factory"
        )
        location.import_default_programme_year_groups!(
          evaluator.programmes,
          academic_year:
        )
      end
    end

    factory :gias_school do
      type { "gias_school" }
      name { Faker::Educator.primary_school }
      with_address

      sequence(:gias_establishment_number, 1)
      sequence(:gias_local_authority_code, 1)
      sequence(:urn, 100_000, &:to_s)

      gias_phase { "all_through" }
      gias_year_groups { (0..11).to_a }

      trait :primary do
        gias_phase { "primary" }
        gias_year_groups { (0..6).to_a }
      end

      trait :secondary do
        name { Faker::Educator.secondary_school }
        gias_phase { "secondary" }
        gias_year_groups { (7..11).to_a }
      end

      after(:build) do |school|
        next if school.gias_local_authority_code.blank?

        LocalAuthority.find_or_create_by!(
          gias_code: school.gias_local_authority_code
        ) do |la|
          la.mhclg_code =
            "E0600#{school.gias_local_authority_code.to_s.rjust(4, "0")}"
          la.official_name =
            "Test Authority #{school.gias_local_authority_code}"
          la.short_name = "Test LA #{school.gias_local_authority_code}"
          la.nation = "England"
        end
      end

      after(:create) do |location, evaluator|
        academic_year = evaluator.academic_year
        subteam = evaluator.subteam

        if (team = evaluator.team)
          team.team_locations.create!(location:, academic_year:, subteam:)
        end

        location.import_year_groups_from_gias!(academic_year:)

        location.import_default_programme_year_groups!(
          evaluator.programmes,
          academic_year:
        )
      end
    end

    factory :gp_practice do
      type { "gp_practice" }
      name { "#{Faker::University.name} Practice" }
      with_address

      sequence(:ods_code, 100) { "GP#{it}" }

      after(:create) do |location, evaluator|
        if (team = evaluator.team)
          academic_year = evaluator.academic_year
          subteam = evaluator.subteam

          team.team_locations.create!(location:, academic_year:, subteam:)
        end
      end
    end
  end
end
