# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records
#
#  id                                          :bigint           not null, primary key
#  batch_expiry                                :date
#  batch_number                                :string
#  confirmation_sent_at                        :datetime
#  delivery_method                             :integer
#  delivery_site                               :integer
#  discarded_at                                :datetime
#  disease_types                               :enum             not null, is an Array
#  dose_sequence                               :integer
#  full_dose                                   :boolean
#  local_patient_id_uri                        :string
#  location_name                               :string
#  nhs_immunisations_api_etag                  :string
#  nhs_immunisations_api_identifier_system     :string
#  nhs_immunisations_api_identifier_value      :string
#  nhs_immunisations_api_primary_source        :boolean
#  nhs_immunisations_api_recorded_at           :datetime
#  nhs_immunisations_api_snomed_procedure_code :string
#  nhs_immunisations_api_snomed_procedure_term :string
#  nhs_immunisations_api_snomed_reason_code    :string
#  nhs_immunisations_api_snomed_reason_term    :string
#  nhs_immunisations_api_sync_pending_at       :datetime
#  nhs_immunisations_api_synced_at             :datetime
#  notes                                       :text
#  notify_parents                              :boolean
#  outcome                                     :integer          not null
#  pending_changes                             :jsonb            not null
#  performed_at_date                           :date             not null
#  performed_at_time                           :time
#  performed_by_family_name                    :string
#  performed_by_given_name                     :string
#  performed_ods_code                          :string
#  programme_type                              :enum             not null
#  protocol                                    :integer
#  source                                      :integer          not null
#  uuid                                        :uuid             not null
#  created_at                                  :datetime         not null
#  updated_at                                  :datetime         not null
#  duplicate_of_vaccination_record_id          :bigint
#  local_patient_id                            :string
#  location_id                                 :bigint
#  next_dose_delay_triage_id                   :bigint
#  nhs_immunisations_api_id                    :string
#  patient_id                                  :bigint           not null
#  performed_by_user_id                        :bigint
#  reported_by_id                              :bigint
#  session_id                                  :bigint
#  supplied_by_user_id                         :bigint
#  vaccine_id                                  :bigint
#
# Indexes
#
#  idx_on_duplicate_of_vaccination_record_id_5071adce87            (duplicate_of_vaccination_record_id)
#  idx_on_patient_id_programme_type_outcome_453b557b54             (patient_id,programme_type,outcome) WHERE (discarded_at IS NULL)
#  index_vaccination_records_on_discarded_at                       (discarded_at)
#  index_vaccination_records_on_location_id                        (location_id)
#  index_vaccination_records_on_next_dose_delay_triage_id          (next_dose_delay_triage_id)
#  index_vaccination_records_on_nhs_immunisations_api_id           (nhs_immunisations_api_id) UNIQUE
#  index_vaccination_records_on_patient_id                         (patient_id)
#  index_vaccination_records_on_patient_id_and_session_id          (patient_id,session_id)
#  index_vaccination_records_on_pending_changes_not_empty          (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_vaccination_records_on_performed_by_user_id               (performed_by_user_id)
#  index_vaccination_records_on_performed_ods_code_and_patient_id  (performed_ods_code,patient_id) WHERE (session_id IS NULL)
#  index_vaccination_records_on_programme_type                     (programme_type)
#  index_vaccination_records_on_reported_by_id                     (reported_by_id)
#  index_vaccination_records_on_session_id                         (session_id)
#  index_vaccination_records_on_supplied_by_user_id                (supplied_by_user_id)
#  index_vaccination_records_on_uuid                               (uuid) UNIQUE
#  index_vaccination_records_on_vaccine_id                         (vaccine_id)
#
# Foreign Keys
#
#  fk_rails_...  (duplicate_of_vaccination_record_id => vaccination_records.id)
#  fk_rails_...  (next_dose_delay_triage_id => triages.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (performed_by_user_id => users.id)
#  fk_rails_...  (reported_by_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#  fk_rails_...  (supplied_by_user_id => users.id)
#  fk_rails_...  (vaccine_id => vaccines.id)
#
FactoryBot.define do
  factory :vaccination_record do
    transient do
      team do
        Team.has_all_programmes_of([programme]).first ||
          association(:team, programmes: [programme])
      end

      batch { build(:batch, :not_expired) if vaccine }
    end

    programme { Programme.sample }

    performed_ods_code { team&.organisation&.ods_code }

    patient do
      association :patient,
                  school:
                    session&.location&.gias_school? ? session.location : nil
    end

    delivery_site { "left_arm_upper_position" }
    delivery_method { "intramuscular" }

    vaccine { programme.vaccines.active.sample if session }
    disease_types { vaccine&.disease_types || programme.disease_types }

    batch_number { batch&.number }
    batch_expiry { batch&.expiry }

    performed_by

    outcome { "administered" }
    performed_at { Time.current }

    dose_sequence { programme.default_dose_sequence }
    full_dose { true }
    protocol { "pgd" }

    uuid { SecureRandom.uuid }
    source { session.present? ? "service" : "historical_upload" }

    location { session&.location unless session&.generic_clinic? }
    location_name { "Unknown" if location.nil? }

    notify_parents { true }

    after(:create) do |vaccination_record|
      PatientTeamUpdater.call(
        patient_scope: Patient.where(id: vaccination_record.patient_id)
      )

      ImportantNoticeGeneratorJob.perform_now([vaccination_record.patient_id])
    end

    trait :sourced_from_nhs_immunisations_api do
      source { "nhs_immunisations_api" }
      nhs_immunisations_api_id { SecureRandom.uuid }
      nhs_immunisations_api_identifier_system { SecureRandom.uuid }
      nhs_immunisations_api_identifier_value { SecureRandom.uuid }
      nhs_immunisations_api_primary_source { true }
    end

    trait :sourced_from_national_reporting do
      transient do
        uploaded_by { nil }
        immunisation_import { nil }
      end

      source { "national_reporting" }
      programme { [Programme.flu, Programme.hpv].sample }

      after(:create) do |vaccination_record, evaluator|
        next unless evaluator.uploaded_by || evaluator.immunisation_import

        immunisation_import =
          if evaluator.immunisation_import
            evaluator.immunisation_import.vaccination_records << vaccination_record

            evaluator.immunisation_import
          else
            create(
              :immunisation_import,
              type: "national_reporting",
              vaccination_records: [vaccination_record],
              team: evaluator.uploaded_by.selected_team,
              uploaded_by: evaluator.uploaded_by
            )
          end

        immunisation_import.patients << vaccination_record.patient

        PatientTeamUpdater.call(
          patient_scope: Patient.where(id: vaccination_record.patient_id)
        )
      end
    end

    trait :sourced_from_manual_report do
      source { "manual_report" }
    end

    trait :with_archived_patient do
      after(:create) do |_vaccination_record, evaluator|
        ArchiveReason.create!(
          patient: evaluator.patient,
          team: evaluator.team,
          type: :immunisation_import
        )
      end
    end

    trait :not_administered do
      delivery_site { nil }
      delivery_method { nil }
      outcome { "unwell" }
      vaccine { nil }
      dose_sequence { nil }
      full_dose { nil }
    end

    trait :already_had do
      not_administered
      outcome { "already_had" }
    end

    trait :contraindicated do
      not_administered
      outcome { "contraindicated" }
    end

    trait :refused do
      not_administered
      outcome { "refused" }
    end

    trait :performed_by_not_user do
      performed_by { nil }
      performed_by_given_name { Faker::Name.first_name }
      performed_by_family_name { Faker::Name.last_name }
    end

    trait :half_dose do
      full_dose { false }
    end

    trait :discarded do
      discarded_at { Time.current }
    end

    trait :confirmation_sent do
      confirmation_sent_at { Time.current }
    end

    trait :yesterday do
      performed_at { 1.day.ago }
    end
  end
end
