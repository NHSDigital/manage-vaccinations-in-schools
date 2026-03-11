# frozen_string_literal: true

# == Schema Information
#
# Table name: sessions
#
#  id                            :bigint           not null, primary key
#  dates                         :date             not null, is an Array
#  days_before_consent_reminders :integer
#  national_protocol_enabled     :boolean          default(FALSE), not null
#  outbreak                      :boolean          default(FALSE), not null
#  psd_enabled                   :boolean          default(FALSE), not null
#  requires_registration         :boolean          default(TRUE), not null
#  send_consent_requests_at      :date
#  slug                          :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  team_location_id              :bigint           not null
#
# Indexes
#
#  index_sessions_on_dates             (dates) USING gin
#  index_sessions_on_team_location_id  (team_location_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_location_id => team_locations.id)
#
FactoryBot.define do
  factory :session do
    transient do
      date { Date.current }
      programmes { [Programme.sample] }

      academic_year { (dates.first || Date.current).academic_year }
      team { association(:team, programmes:) }
      location { association(:school, programmes:, academic_year:) }
    end

    sequence(:slug) { |n| "session-#{n}" }

    dates { [date].compact }
    team_location do
      TeamLocation.find_or_create_by!(team:, location:, academic_year:)
    end

    days_before_consent_reminders do
      if dates.first && !location.generic_clinic?
        team.days_before_consent_reminders
      end
    end
    send_consent_requests_at do
      if dates.first && !location.generic_clinic?
        (dates.first - team.days_before_consent_requests.days)
      end
    end

    after(:create) do |session, evaulator|
      session.sync_location_programme_year_groups!(
        programme_types: evaulator.programmes.map(&:type)
      )
    end

    trait :today do
      date { Date.current }
    end

    trait :tomorrow do
      date { Date.tomorrow }
    end

    trait :yesterday do
      date { Date.yesterday }
    end

    trait :tomorrow do
      date { Date.tomorrow }
    end

    trait :unscheduled do
      date { nil }
    end

    trait :scheduled do
      date { Date.current + 1.week }
    end

    trait :completed do
      date { Date.current - 1.week }
    end

    trait :requires_no_registration do
      requires_registration { false }
    end

    trait :psd_enabled do
      psd_enabled { true }
    end

    trait :national_protocol_enabled do
      national_protocol_enabled { true }
    end
  end
end
