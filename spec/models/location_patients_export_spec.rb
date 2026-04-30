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
describe LocationPatientsExport do
  subject(:export) { create(:location_patients_export) }

  describe "associations" do
    it { should belong_to(:location) }
  end

  describe "#name" do
    subject(:name) { export.name }

    context "when location is a clinic" do
      it { should eq("Community clinic offline session") }
    end

    context "when location is a school" do
      let(:export) do
        create(:location_patients_export, location: create(:gias_school))
      end

      it { should eq("#{export.location.name} offline session") }
    end
  end

  describe "#filename" do
    subject(:filename) { export.filename }

    it "returns a filename with name and export date" do
      date_str = export.created_at.to_date.to_fs(:long)

      expect(filename).to match(/#{date_str}/)
    end
  end
end
