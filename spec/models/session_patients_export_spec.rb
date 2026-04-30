# frozen_string_literal: true

# == Schema Information
#
# Table name: session_patients_exports
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  session_id :bigint           not null
#
# Foreign Keys
#
#  fk_rails_...  (session_id => sessions.id)
#
describe SessionPatientsExport do
  subject(:export) { create(:session_patients_export, session:) }

  let(:programme) { Programme.hpv }
  let(:team) { create(:team, :with_one_nurse, programmes: [programme]) }
  let(:location) { create(:gias_school, team:, programmes: [programme]) }
  let(:session) { create(:session, team:, location:, programmes: [programme]) }

  it { should be_valid }

  describe "#name" do
    subject { export.name }

    it { should eq("#{location.name} offline session") }
  end

  describe "#filename" do
    subject(:filename) { export.filename }

    it "includes location name, URN/site, and export date" do
      date_str = export.created_at.to_date.to_fs(:long)
      expect(filename).to eq(
        "#{location.name} (#{location.urn_and_site}) - exported on #{date_str}.xlsx"
      )
    end
  end
end
