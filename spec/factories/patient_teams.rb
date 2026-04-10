# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_teams
#
#  sources    :integer          not null, is an Array
#  patient_id :bigint           not null, primary key
#  team_id    :bigint           not null, primary key
#
# Indexes
#
#  index_patient_teams_on_patient_id              (patient_id)
#  index_patient_teams_on_patient_id_and_team_id  (patient_id,team_id)
#  index_patient_teams_on_sources                 (sources) USING gin
#  index_patient_teams_on_team_id                 (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#  fk_rails_...  (team_id => teams.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :patient_team do
    patient
    team

    sources { %i[patient_location] }

    trait :patient_location do
      sources { %i[patient_location] }
    end

    trait :archive_reason do
      sources { %i[archive_reason] }
    end

    trait :vaccination_record_session do
      sources { %i[vaccination_record_session] }
    end

    trait :school_move_school do
      sources { %i[school_move_school] }
    end
  end
end
