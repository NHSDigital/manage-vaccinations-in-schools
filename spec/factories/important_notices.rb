# frozen_string_literal: true

# == Schema Information
#
# Table name: important_notices
#
#  id                       :bigint           not null, primary key
#  dismissed_at             :datetime
#  recorded_at              :datetime         not null
#  type                     :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  dismissed_by_user_id     :bigint
#  patient_id               :bigint           not null
#  school_move_log_entry_id :bigint
#  team_id                  :bigint           not null
#  vaccination_record_id    :bigint
#
# Indexes
#
#  index_important_notices_on_dismissed_by_user_id             (dismissed_by_user_id)
#  index_important_notices_on_patient_id                       (patient_id)
#  index_important_notices_on_school_move_log_entry_id         (school_move_log_entry_id)
#  index_important_notices_on_team_id                          (team_id)
#  index_important_notices_on_vaccination_record_id            (vaccination_record_id)
#  index_notices_on_patient_and_type_and_recorded_at_and_team  (patient_id,type,recorded_at,team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (dismissed_by_user_id => users.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_move_log_entry_id => school_move_log_entries.id)
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (vaccination_record_id => vaccination_records.id)
#
FactoryBot.define do
  factory :important_notice do
    patient
    team_id { create(:team).id }

    type { ImportantNotice.types.keys.sample }
    recorded_at { Time.current }

    after(:build) do |notice|
      if notice.type == "gillick_no_notify" && notice.vaccination_record.nil?
        notice.vaccination_record = build(:vaccination_record)
      elsif notice.type == "team_changed" && notice.school_move_log_entry.nil?
        school = create(:gias_school, team: Team.find(notice.team_id))
        notice.school_move_log_entry = build(:school_move_log_entry, school:)
      end
    end

    trait :deceased do
      type { :deceased }
    end

    trait :restricted do
      type { :restricted }
    end

    trait :invalidated do
      type { :invalidated }
    end

    trait :gillick_no_notify do
      type { :gillick_no_notify }
      vaccination_record
    end

    trait :dismissed do
      dismissed_at { 1.day.ago }
      dismissed_by_user { association :user }
    end
  end
end
