# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_form_programmes
#
#  id                  :bigint           not null, primary key
#  disease_types       :enum             is an Array
#  follow_up_requested :boolean
#  notes               :text             default(""), not null
#  programme_type      :enum             not null
#  reason_for_refusal  :integer
#  response            :integer
#  vaccine_methods     :integer          default([]), not null, is an Array
#  without_gelatine    :boolean
#  consent_form_id     :bigint           not null
#
# Indexes
#
#  idx_on_programme_type_consent_form_id_805eb5d685  (programme_type,consent_form_id) UNIQUE
#  index_consent_form_programmes_on_consent_form_id  (consent_form_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :consent_form_programme do
    consent_form
    programme { Programme.sample }
    disease_types do
      if programme.mmr?
        programme.variants.sample.disease_types
      else
        Programme::DISEASE_TYPES[programme.type]
      end
    end

    trait :given do
      response { "given" }
      vaccine_methods { %w[injection] }
      without_gelatine { false }
    end

    trait :refused do
      response { "refused" }
    end
  end
end
