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
#  location_id   :bigint           not null
#  patient_id    :bigint           not null
#  school_id     :bigint
#
# Indexes
#
#  idx_on_location_id_academic_year_patient_id_3237b32fa0    (location_id,academic_year,patient_id) UNIQUE
#  idx_on_patient_id_location_id_academic_year_08a1dc4afe    (patient_id,location_id,academic_year) UNIQUE
#  idx_on_patient_id_school_id_academic_year_652216fa07      (patient_id,school_id,academic_year) UNIQUE
#  idx_on_school_id_academic_year_patient_id_c647e75f26      (school_id,academic_year,patient_id) UNIQUE
#  index_patient_locations_on_location_id                    (location_id)
#  index_patient_locations_on_location_id_and_academic_year  (location_id,academic_year)
#  index_patient_locations_on_school_id                      (school_id)
#  index_patient_locations_on_school_id_and_academic_year    (school_id,academic_year)
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#
FactoryBot.define do
  factory :patient_location do
    transient { session { association(:session) } }

    patient
    location { session.location }
    academic_year { session.academic_year }

    after(:create) do |patient_location|
      PatientTeamUpdater.call(
        patient_scope: Patient.where(id: patient_location.patient_id),
        team_scope: patient_location.location.teams
      )
    end
  end
end
