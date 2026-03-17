# frozen_string_literal: true

# == Schema Information
#
# Table name: location_year_groups
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  source        :integer          not null
#  value         :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  location_id   :bigint           not null
#
# Indexes
#
#  idx_on_location_id_academic_year_value_d553b03752  (location_id,academic_year,value) UNIQUE
#  index_location_year_groups_on_location_id          (location_id)
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :location_year_group, class: "Location::YearGroup" do
    location

    academic_year { AcademicYear.pending }
    value { Location::YearGroup::DEFAULT_VALUE_RANGE.to_a.sample }

    source { Location::YearGroup.sources.keys.sample }

    traits_for_enum :source
  end
end
