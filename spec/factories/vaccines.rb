# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccines
#
#  id                  :bigint           not null, primary key
#  brand               :text             not null
#  contains_gelatine   :boolean          not null
#  discontinued        :boolean          default(FALSE), not null
#  disease_types       :enum             default([]), not null, is an Array
#  dose_volume_ml      :decimal(, )      not null
#  manufacturer        :text             not null
#  method              :integer          not null
#  nivs_name           :string
#  programme_type      :enum             not null
#  side_effects        :integer          default([]), not null, is an Array
#  snomed_product_code :string           not null
#  snomed_product_term :string           not null
#  upload_name         :text             not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_vaccines_on_manufacturer_and_brand  (manufacturer,brand) UNIQUE
#  index_vaccines_on_programme_type          (programme_type)
#  index_vaccines_on_snomed_product_code     (snomed_product_code) UNIQUE
#  index_vaccines_on_snomed_product_term     (snomed_product_term) UNIQUE
#  index_vaccines_on_upload_name             (upload_name) UNIQUE
#
FactoryBot.define do
  factory :vaccine do
    transient { programme { nil } }

    programme_type { programme&.type || Programme::TYPES.sample }
    disease_types { Programme::DISEASE_TYPES[programme_type] }
    brand { Faker::Commerce.product_name }
    manufacturer { Faker::Company.name }
    sequence(:upload_name) { |n| "#{brand.parameterize}-#{n}" }
    dose_volume_ml { Faker::Number.decimal(l_digits: 0) }
    snomed_product_code { Faker::Number.decimal_part(digits: 17) }
    snomed_product_term { Faker::Lorem.sentence }
    add_attribute(:method) { %i[nasal injection].sample }
    contains_gelatine { false }

    traits_for_enum :method

    trait :discontinued do
      discontinued { true }
    end

    trait :contains_gelatine do
      contains_gelatine { true }
    end

    trait :flu do
      programme_type { "flu" }

      after(:create) do |vaccine|
        if vaccine.nasal?
          asthma = create(:health_question, :asthma, vaccine:)
          steroids = create(:health_question, :steroids, vaccine:)
          intensive_care = create(:health_question, :intensive_care, vaccine:)
          immune_system = create(:health_question, :immune_system, vaccine:)
          household_immune_system =
            create(:health_question, :household_immune_system, vaccine:)
          egg_allergy = create(:health_question, :egg_allergy, vaccine:)
          allergies = create(:health_question, :allergies, vaccine:)
          reaction = create(:health_question, :reaction, vaccine:)
          aspirin = create(:health_question, :aspirin, vaccine:)
          flu_vaccination = create(:health_question, :flu_vaccination, vaccine:)

          asthma.update! next_question: immune_system
          asthma.update! follow_up_question: steroids
          steroids.update! next_question: intensive_care
          intensive_care.update! next_question: immune_system

          immune_system.update! next_question: household_immune_system
          household_immune_system.update! next_question: egg_allergy
          egg_allergy.update! next_question: allergies
          allergies.update! next_question: reaction
          reaction.update! next_question: aspirin
          aspirin.update! next_question: flu_vaccination
        else
          bleeding_disorder =
            create(:health_question, :bleeding_disorder, vaccine:)
          allergies = create(:health_question, :allergies, vaccine:)
          reaction = create(:health_question, :reaction, vaccine:)
          flu_vaccination = create(:health_question, :flu_vaccination, vaccine:)

          bleeding_disorder.update! next_question: allergies
          allergies.update! next_question: reaction
          reaction.update! next_question: flu_vaccination
        end
      end
    end

    trait :hpv do
      programme_type { "hpv" }

      after(:create) do |vaccine|
        severe_allergies = create(:health_question, :severe_allergies, vaccine:)
        medical_conditions =
          create(:health_question, :medical_conditions, vaccine:)
        severe_reaction = create(:health_question, :severe_reaction, vaccine:)
        extra_support = create(:health_question, :extra_support, vaccine:)

        severe_allergies.update!(next_question: medical_conditions)
        medical_conditions.update!(next_question: severe_reaction)
        severe_reaction.update!(next_question: extra_support)
      end
    end

    trait :menacwy do
      programme_type { "menacwy" }

      after(:create) do |vaccine|
        bleeding_disorder =
          create(:health_question, :bleeding_disorder, vaccine:)
        severe_allergies = create(:health_question, :severe_allergies, vaccine:)
        severe_reaction = create(:health_question, :severe_reaction, vaccine:)
        extra_support = create(:health_question, :extra_support, vaccine:)
        menacwy_vaccination =
          create(:health_question, :menacwy_vaccination, vaccine:)

        bleeding_disorder.update!(next_question: severe_allergies)
        severe_allergies.update!(next_question: severe_reaction)
        severe_reaction.update!(next_question: extra_support)
        extra_support.update!(next_question: menacwy_vaccination)
      end
    end

    trait :mmr do
      programme_type { "mmr" }
      disease_types { Programme::Variant::DISEASE_TYPES["mmr"] }
      injection

      after(:create) do |vaccine|
        bleeding_disorder =
          create(:health_question, :bleeding_disorder, vaccine:)
        mmr_vaccination = create(:health_question, :mmr_vaccination, vaccine:)
        extra_support = create(:health_question, :extra_support, vaccine:)

        bleeding_disorder.update!(next_question: mmr_vaccination)
        mmr_vaccination.update!(next_question: extra_support)
      end
    end

    trait :mmrv do
      programme_type { "mmr" }
      disease_types { Programme::Variant::DISEASE_TYPES["mmrv"] }
      injection

      after(:create) do |vaccine|
        bleeding_disorder =
          create(:health_question, :bleeding_disorder, vaccine:)
        mmrv_vaccination = create(:health_question, :mmrv_vaccination, vaccine:)
        extra_support = create(:health_question, :extra_support, vaccine:)

        bleeding_disorder.update!(next_question: mmrv_vaccination)
        mmrv_vaccination.update!(next_question: extra_support)
      end
    end

    trait :td_ipv do
      programme_type { "td_ipv" }

      after(:create) do |vaccine|
        bleeding_disorder =
          create(:health_question, :bleeding_disorder, vaccine:)
        severe_allergies = create(:health_question, :severe_allergies, vaccine:)
        severe_reaction = create(:health_question, :severe_reaction, vaccine:)
        td_ipv_vaccination =
          create(:health_question, :td_ipv_vaccination, vaccine:)
        extra_support = create(:health_question, :extra_support, vaccine:)

        bleeding_disorder.update!(next_question: severe_allergies)
        severe_allergies.update!(next_question: severe_reaction)
        severe_reaction.update!(next_question: extra_support)
        extra_support.update!(next_question: td_ipv_vaccination)
      end
    end

    all_data = YAML.load_file(Rails.root.join("config/vaccines.yml"))

    all_data.each do |key, data|
      trait key do
        send(data["type"])
        brand { data["brand"] }
        contains_gelatine { data["contains_gelatine"] }
        discontinued { data.fetch("discontinued", false) }
        dose_volume_ml { data["dose_volume_ml"] }
        disease_types { data["disease_types"] }
        manufacturer { data["manufacturer"] }
        add_attribute(:method) { data["method"] }
        upload_name { data["upload_name"] }
        nivs_name { data["nivs_name"] }
        snomed_product_code { data["snomed_product_code"] }
        snomed_product_term { data["snomed_product_term"] }
      end
    end

    before(:create) do |_vaccine, _evaluator|
      unless Vaccine.enable_factorybot_factories
        raise "Do not create vaccines in tests. " \
                "This introduces dependencies between tests as they get cached " \
                "on the programme and then deleted from the database."
      end
    end
  end
end
