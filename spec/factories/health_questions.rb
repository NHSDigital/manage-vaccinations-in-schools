# frozen_string_literal: true

# == Schema Information
#
# Table name: health_questions
#
#  id                    :bigint           not null, primary key
#  give_details_hint     :string
#  hint                  :string
#  metadata              :jsonb            not null
#  title                 :string           not null
#  would_require_triage  :boolean          default(TRUE), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  follow_up_question_id :bigint
#  next_question_id      :bigint
#  vaccine_id            :bigint           not null
#
# Indexes
#
#  index_health_questions_on_follow_up_question_id  (follow_up_question_id)
#  index_health_questions_on_next_question_id       (next_question_id)
#  index_health_questions_on_vaccine_id             (vaccine_id)
#
# Foreign Keys
#
#  fk_rails_...  (follow_up_question_id => health_questions.id)
#  fk_rails_...  (next_question_id => health_questions.id)
#  fk_rails_...  (vaccine_id => vaccines.id)
#
FactoryBot.define do
  factory :health_question do
    vaccine
    title { Faker::Lorem.question }

    trait :wouldnt_require_triage do
      would_require_triage { false }
    end

    trait :severe_allergies do
      title { "Does your child have any severe allergies?" }
    end

    trait :medical_conditions do
      title do
        "Does your child have any medical conditions for which they receive treatment?"
      end
    end

    trait :severe_reaction do
      title do
        "Has your child ever had a severe reaction to any medicines, including vaccines?"
      end
    end

    trait :extra_support do
      title do
        "Does your child need extra support during vaccination sessions?"
      end
      hint { "For example, they’re autistic, or extremely anxious" }
    end

    trait :bleeding_disorder do
      title do
        "Does your child have a bleeding disorder or another medical condition they receive treatment for?"
      end
    end

    trait :menacwy_vaccination do
      title do
        "Has your child had a meningitis (MenACWY) vaccination in the last 5 years?"
      end
      hint do
        "It’s usually given once in Year 9 or 10. Some children may have had it before travelling abroad."
      end
    end

    trait :td_ipv_vaccination do
      title do
        "Has your child had a tetanus, diphtheria and polio vaccination in the last 5 years?"
      end
      hint do
        "Most children will not have had this vaccination since their 4-in-1 pre-school booster"
      end
    end

    trait :asthma do
      title { "Has your child been diagnosed with asthma?" }
      wouldnt_require_triage # has follow up questions
    end

    trait :steroids do
      title { "Have they taken oral steroids in the last 2 weeks?" }
    end

    trait :intensive_care do
      title { "Have they been admitted to intensive care for their asthma?" }
    end

    trait :flu_vaccination do
      title { "Has your child had a flu vaccination in the last 5 months?" }
    end

    trait :immune_system do
      title do
        "Does your child have a disease or treatment that severely affects their immune system?"
      end
      hint do
        "For example, treatment for leukaemia or taking immunosuppressant medication"
      end
    end

    trait :household_immune_system do
      title do
        "Is anyone in your household currently having treatment that severely affects their immune system?"
      end
      hint { "For example, they need to be kept in isolation" }
    end

    trait :egg_allergy do
      title do
        "Has your child ever been admitted to intensive care due to an allergic reaction to egg?"
      end
    end

    trait :allergies do
      title { "Does your child have any allergies to medication?" }
    end

    trait :reaction do
      title { "Has your child ever had a reaction to previous vaccinations?" }
    end

    trait :aspirin do
      title { "Does you child take regular aspirin?" }
      hint { "Also known as Salicylate therapy" }
    end

    trait :mmr_vaccination do
      title do
        "Has your child had a severe allergic reaction (anaphylaxis) to a " \
          "previous dose of MMR or any other measles, mumps or rubella vaccine?"
      end
    end

    trait :mmrv_vaccination do
      title do
        "Has your child had a severe allergic reaction (anaphylaxis) to a " \
          "previous dose of MMRV or any other measles, mumps, rubella or varicella (chickenpox) vaccine?"
      end
    end
  end
end
