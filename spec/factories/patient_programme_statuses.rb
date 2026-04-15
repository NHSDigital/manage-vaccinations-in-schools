# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_programme_statuses
#
#  id                      :bigint           not null, primary key
#  academic_year           :integer          not null
#  consent_status          :integer          default("no_response"), not null
#  consent_vaccine_methods :integer          default([]), not null, is an Array
#  date                    :date
#  disease_types           :enum             is an Array
#  dose_sequence           :integer
#  programme_type          :enum             not null
#  status                  :integer          default("not_eligible"), not null
#  vaccine_methods         :integer          is an Array
#  without_gelatine        :boolean
#  location_id             :bigint
#  patient_id              :bigint           not null
#
# Indexes
#
#  idx_on_academic_year_patient_id_3d5bf8d2c8                 (academic_year,patient_id)
#  idx_on_patient_id_academic_year_programme_type_75e0e0c471  (patient_id,academic_year,programme_type) UNIQUE
#  index_patient_programme_statuses_on_location_id            (location_id)
#  index_patient_programme_statuses_on_patient_id             (patient_id)
#  index_patient_programme_statuses_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :patient_programme_status, class: "Patient::ProgrammeStatus" do
    patient
    programme { Programme.sample }
    academic_year { AcademicYear.current }

    traits_for_enum :status

    trait :cannot_vaccinate_delay_vaccination do
      status { "cannot_vaccinate_delay_vaccination" }
      date { Date.tomorrow }
    end

    trait :has_refusal_consent_refused do
      consent_status { "refused" }
      status { "has_refusal_consent_refused" }
    end

    trait :has_refusal_consent_conflicts do
      consent_status { "conflicts" }
      status { "has_refusal_consent_conflicts" }
    end

    trait :needs_consent_follow_up_requested do
      consent_status { "follow_up_requested" }
      status { "needs_consent_follow_up_requested" }
    end

    trait :needs_consent_no_contact_details do
      consent_status { "no_contact_details" }
      status { "needs_consent_no_contact_details" }
    end

    trait :needs_triage do
      consent_status { "given" }
      consent_vaccine_methods { %w[injection] }
      status { "needs_triage" }
    end

    trait :due_injection do
      consent_status { "given" }
      consent_vaccine_methods { %w[injection] }
      status { "due" }
      vaccine_methods { %w[injection] }
      without_gelatine { false }
    end

    trait :due_injection_without_gelatine do
      consent_status { "given" }
      consent_vaccine_methods { %w[injection] }
      status { "due" }
      vaccine_methods { %w[injection] }
      without_gelatine { true }
    end

    trait :due_nasal_injection do
      consent_status { "given" }
      consent_vaccine_methods { %w[nasal injection] }
      status { "due" }
      vaccine_methods { %w[nasal injection] }
      without_gelatine { false }
    end

    trait :due_nasal do
      consent_status { "given" }
      consent_vaccine_methods { %w[nasal] }
      status { "due" }
      vaccine_methods { %w[nasal] }
      without_gelatine { false }
    end
  end
end
