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
describe Location::YearGroup do
  subject(:location_year_group) { build(:location_year_group, location:) }

  let(:location) { create(:gias_school) }

  describe "associations" do
    it { should belong_to(:location) }
  end

  describe "validations" do
    it { should validate_presence_of(:value) }

    it do
      expect(location_year_group).to validate_uniqueness_of(:value).scoped_to(
        :location_id,
        :academic_year
      )
    end
  end
end
