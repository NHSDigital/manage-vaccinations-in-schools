# frozen_string_literal: true

# == Schema Information
#
# Table name: location_patients_exports
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  filter_params :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  location_id   :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#
FactoryBot.define do
  factory :location_patients_export do
    academic_year { AcademicYear.current }
    filter_params { {} }
    association :location, factory: :generic_clinic
  end
end
