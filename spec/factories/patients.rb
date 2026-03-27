# frozen_string_literal: true

# == Schema Information
#
# Table name: patients
#
#  id                         :bigint           not null, primary key
#  address_line_1             :string
#  address_line_2             :string
#  address_postcode           :string
#  address_town               :string
#  birth_academic_year        :integer          not null
#  date_of_birth              :date             not null
#  date_of_death              :date
#  date_of_death_recorded_at  :datetime
#  ethnic_background          :integer
#  ethnic_background_other    :string
#  ethnic_group               :integer
#  family_name                :string           not null
#  gender_code                :integer          default("not_known"), not null
#  given_name                 :string           not null
#  invalidated_at             :datetime
#  local_authority_mhclg_code :string
#  nhs_number                 :string
#  pending_changes            :jsonb            not null
#  preferred_family_name      :string
#  preferred_given_name       :string
#  registration               :string
#  registration_academic_year :integer
#  restricted_at              :datetime
#  updated_from_pds_at        :datetime
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  gp_practice_id             :bigint
#  school_id                  :bigint
#
# Indexes
#
#  index_patients_on_family_name_trigram                  (family_name) USING gin
#  index_patients_on_given_name_trigram                   (given_name) USING gin
#  index_patients_on_gp_practice_id                       (gp_practice_id)
#  index_patients_on_local_authority_mhclg_code           (local_authority_mhclg_code)
#  index_patients_on_lower_family_name_dob_address        (date_of_birth, address_postcode, lower((family_name)::text))
#  index_patients_on_lower_given_name_dob_address         (address_postcode, date_of_birth, lower((given_name)::text))
#  index_patients_on_lower_names_family_first_address     (lower((family_name)::text), lower((given_name)::text), address_postcode)
#  index_patients_on_lower_names_given_first_dob_address  (lower((given_name)::text), lower((family_name)::text), date_of_birth, address_postcode)
#  index_patients_on_names_family_first                   (family_name,given_name)
#  index_patients_on_names_given_first                    (given_name,family_name)
#  index_patients_on_nhs_number                           (nhs_number) UNIQUE
#  index_patients_on_pending_changes_not_empty            (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_patients_on_school_id                            (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (gp_practice_id => locations.id)
#  fk_rails_...  (school_id => locations.id)
#

require_relative "../../lib/faker/address"

FactoryBot.define do
  sequence :nhs_number_counter, 1

  factory :patient do
    transient do
      academic_year { session&.academic_year || AcademicYear.current }
      location { session&.location || school }
      location_name { nil }
      parents { [] }
      performed_by { association(:user) }
      programmes { session&.programmes || [] }
      random_nhs_number { false }
      session { nil }
      team { session&.team || school&.team || create(:team, programmes:) }
      year_group { programmes.flat_map(&:default_year_groups).sort.uniq.first }
    end

    nhs_number do
      if random_nhs_number
        Faker::NationalHealthService.british_number.gsub(" ", "")
      else
        # Faker doesn't allow us to generate sequential NHS numbers, so this is
        # reimplemented here.
        #
        # https://github.com/faker-ruby/faker/blob/6ba06393f47d4018b5fdbdaaa04eb9891ae5fb55/lib/faker/default/national_health_service.rb
        base = 999_000_000 + generate(:nhs_number_counter)
        sum = base.to_s.chars.map.with_index { |d, i| d.to_i * (10 - i) }.sum
        check_digit = (11 - (sum % 11)) % 11
        redo if check_digit == 10 # Retry if check digit is 10, which is invalid

        "#{base}#{check_digit}"
      end
    end

    given_name { Faker::Name.first_name }
    family_name { Faker::Name.last_name }

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
    birth_academic_year do
      if year_group
        year_group.to_birth_academic_year(academic_year:)
      else
        date_of_birth.academic_year
      end
    end

    registration { Faker::Alphanumeric.alpha(number: 2).upcase }
    registration_academic_year { academic_year if registration.present? }

    school { session.location if session&.location&.school? }

    address_line_1 { Faker::Address.street_address }
    address_line_2 { Faker::Address.secondary_address }
    address_town { Faker::Address.city }
    address_postcode { Faker::Address.uk_postcode }

    ethnic_group { ConsentForm.ethnic_backgrounds_by_group.keys.sample }

    ethnic_background do
      ConsentForm.ethnic_backgrounds_for_group(ethnic_group).sample
    end

    ethnic_background_other do
      if ConsentForm.any_other_ethnic_backgrounds.include?(ethnic_background)
        "Any other background details"
      end
    end

    parent_relationships do
      parents.map do |parent|
        association(:parent_relationship, patient: instance, parent:)
      end
    end

    after(:create) do |patient, evaluator|
      if (academic_year = evaluator.academic_year)
        [evaluator.location, evaluator.school].uniq.compact.each do |location|
          create(:patient_location, patient:, location:, academic_year:)
        end
      end
    end

    trait :in_attendance do
      after(:create) do |patient, evaluator|
        if (session = evaluator.session)
          create(:attendance_record, :present, patient:, session:)
          create(:patient_registration_status, :attending, patient:, session:)
        end
      end
    end

    trait :unknown_attendance do
      after(:create) do |patient, evaluator|
        if (session = evaluator.session)
          create(:patient_registration_status, patient:, session:)
        end
      end
    end

    trait :home_educated do
      team { session&.team || create(:team, programmes:) }
      school { team.home_educated_school }
    end

    trait :deceased do
      date_of_death { Date.current }
      date_of_death_recorded_at { Time.current }
      after(:create) do |instance|
        ImportantNoticeGeneratorJob.perform_now([instance.id])
      end
    end

    trait :invalidated do
      invalidated_at { Time.current }
      after(:create) do |instance|
        ImportantNoticeGeneratorJob.perform_now([instance.id])
      end
    end

    trait :restricted do
      restricted_at { Time.current }
      after(:create) do |instance|
        ImportantNoticeGeneratorJob.perform_now([instance.id])
      end
    end

    trait :archived do
      after(:create) do |patient, evaluator|
        create(
          :archive_reason,
          :moved_out_of_area,
          team: evaluator.team,
          patient:
        )
      end
    end

    trait :consent_request_sent do
      after(:create) do |patient, evaluator|
        create(
          :consent_notification,
          :request,
          patient:,
          session:
            evaluator.session ||
              create(:session, programmes: evaluator.programmes),
          programmes: evaluator.programmes,
          sent_at: 1.week.ago
        )
      end
    end

    trait :initial_consent_reminder_sent do
      after(:create) do |patient, evaluator|
        create(
          :consent_notification,
          :initial_reminder,
          patient:,
          session:
            evaluator.session ||
              create(:session, programmes: evaluator.programmes),
          programmes: evaluator.programmes
        )
      end
    end

    trait :consent_no_response do
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :needs_consent_no_response,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_triage_not_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given,
            :from_mum,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_injection,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_nasal_only_triage_not_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal,
            :from_mum,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_nasal,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_injection_only_triage_not_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_injection,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_injection,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_nasal_or_injection_triage_not_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal_or_injection,
            :from_mum,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_nasal_injection,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_triage_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given,
            :from_mum,
            :health_question_notes,
            patient: instance,
            programme:,
            team:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :needs_triage,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_injection_only_triage_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_injection,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :needs_triage,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_nasal_only_triage_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :needs_triage,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_without_gelatine_triage_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_without_gelatine,
            :from_mum,
            :health_question_notes,
            patient: instance,
            programme:,
            team:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :needs_triage,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_without_gelatine_triage_not_needed do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_without_gelatine,
            :from_mum,
            patient: instance,
            programme:,
            team:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_injection_without_gelatine,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_triage_safe_to_vaccinate do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end

      triages do
        programmes.map do |programme|
          association(
            :triage,
            :safe_to_vaccinate,
            patient: instance,
            performed_by:,
            programme:,
            team:,
            notes: "Okay to vaccinate"
          )
        end
      end

      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_injection,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_injection_and_nasal_triage_safe_to_vaccinate_nasal do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_nasal,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_nasal_triage_safe_to_vaccinate_nasal do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end

      triages do
        programmes.map do |programme|
          association(
            :triage,
            :safe_to_vaccinate_nasal,
            patient: instance,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_nasal,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_injection_and_nasal_triage_safe_to_vaccinate_injection do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :given_nasal_or_injection,
            :from_mum,
            :health_question_notes,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      triages do
        programmes.map do |programme|
          association(
            :triage,
            :safe_to_vaccinate_without_gelatine,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :due_injection_without_gelatine,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_refused do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :refused,
            :from_mum,
            patient: instance,
            team:,
            programme:
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :has_refusal_consent_refused,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_refused_with_notes do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :refused,
            :from_mum,
            patient: instance,
            team:,
            programme:,
            reason_for_refusal: "already_vaccinated",
            notes: "Already had the vaccine at the GP"
          )
        end
      end
    end

    trait :consent_conflicting do
      consents do
        programmes.flat_map do |programme|
          [
            association(
              :consent,
              :refused,
              :from_mum,
              patient: instance,
              team:,
              programme:
            ),
            association(
              :consent,
              :given,
              :from_dad,
              patient: instance,
              team:,
              programme:
            )
          ]
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :has_refusal_consent_conflicts,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_not_provided do
      consents do
        programmes.map do |programme|
          association(
            :consent,
            :not_provided,
            :from_mum,
            patient: instance,
            team:,
            programme:
          )
        end
      end
    end

    trait :partially_vaccinated_triage_needed do
      consent_given_triage_needed

      vaccination_records do
        programmes.map do |programme|
          association(
            :vaccination_record,
            patient: instance,
            performed_by:,
            programme:,
            dose_sequence: 1
          )
        end
      end
    end

    trait :triage_do_not_vaccinate do
      triages do
        programmes.map do |programme|
          association(
            :triage,
            :do_not_vaccinate,
            patient: instance,
            performed_by:,
            programme:,
            team:,
            notes: "Do not vaccinate"
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :cannot_vaccinate_do_not_vaccinate,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :consent_given_triage_invite_to_clinic do
      consent_given_triage_needed

      triages do
        programmes.map do |programme|
          association(
            :triage,
            :invite_to_clinic,
            patient: instance,
            performed_by:,
            programme:,
            team:,
            notes: "Invite to clinic"
          )
        end
      end
    end

    trait :consent_given_triage_delay_vaccination do
      consent_given_triage_needed

      triages do
        programmes.map do |programme|
          association(
            :triage,
            :delay_vaccination,
            patient: instance,
            performed_by:,
            programme:,
            team:,
            notes: "Delay vaccination"
          )
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :cannot_vaccinate_delay_vaccination,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :unable_to_vaccinate do
      consent_given_triage_not_needed

      vaccination_records do
        programmes.map do |programme|
          if session
            association(
              :vaccination_record,
              :not_administered,
              patient: instance,
              performed_by:,
              programme:,
              session:,
              location_name:
            )
          else
            association(
              :vaccination_record,
              :not_administered,
              patient: instance,
              performed_by:,
              programme:
            )
          end
        end
      end
    end

    trait :vaccinated do
      vaccination_records do
        programmes.map do |programme|
          if session
            association(
              :vaccination_record,
              patient: instance,
              performed_by:,
              programme:,
              session:,
              location_name:
            )
          else
            association(
              :vaccination_record,
              patient: instance,
              performed_by:,
              programme:
            )
          end
        end
      end
      programme_statuses do
        programmes.map do |programme|
          association(
            :patient_programme_status,
            :vaccinated_fully,
            patient: instance,
            programme:
          )
        end
      end
    end

    trait :in_national_reporting_upload do
      after(:create) do |patient, evaluator|
        create(
          :archive_reason,
          :immunisation_import,
          team: evaluator.team,
          patient:
        )
      end
    end

    trait :with_vaccinations_search do
      transient { last_searched_at { 28.days.ago } }

      after(:create) do |patient, evaluator|
        evaluator.programmes.each do |programme|
          create(
            :patient_programme_vaccinations_search,
            programme:,
            patient:,
            last_searched_at: evaluator.last_searched_at
          )
        end
      end
    end
  end
end
