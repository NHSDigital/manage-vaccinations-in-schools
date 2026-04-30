# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_locations
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  date_range    :daterange        default(-Infinity...Infinity), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint           not null
#
# Indexes
#
#  idx_on_patient_id_school_id_academic_year_652216fa07    (patient_id,school_id,academic_year) UNIQUE
#  idx_on_school_id_academic_year_patient_id_c647e75f26    (school_id,academic_year,patient_id) UNIQUE
#  index_patient_locations_on_school_id                    (school_id)
#  index_patient_locations_on_school_id_and_academic_year  (school_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#
FactoryBot.define do
  factory :patient_location do
    transient { session { association(:session) } }

    patient
    school { session.location }
    academic_year { session.academic_year }

    after(:create) do |patient_location|
      PatientTeamUpdater.call(
        patient_scope: Patient.where(id: patient_location.patient_id),
        team_scope: patient_location.school.teams
      )
    end
  end
end
