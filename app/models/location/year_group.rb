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
class Location::YearGroup < ApplicationRecord
  audited associated_with: :location

  belongs_to :location

  has_many :location_programme_year_groups,
           class_name: "Location::ProgrammeYearGroup",
           foreign_key: :location_year_group_id,
           dependent: :destroy

  enum :source,
       { gias: 0, generic_location_factory: 1, cli: 2, manual: 3 },
       validate: true

  DEFAULT_VALUE_RANGE = (-3..15)

  validates :value,
            presence: true,
            uniqueness: {
              scope: %i[location_id academic_year]
            }

  scope :pluck_values, -> { distinct.order(:value).pluck(:value) }

  def birth_academic_year = value.to_birth_academic_year(academic_year:)

  def programmes
    location_programme_year_groups.map(&:programme).sort.uniq
  end
end
