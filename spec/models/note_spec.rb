# frozen_string_literal: true

# == Schema Information
#
# Table name: notes
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  created_by_user_id :bigint           not null
#  patient_id         :bigint           not null
#  session_id         :bigint
#
# Indexes
#
#  index_notes_on_created_by_user_id  (created_by_user_id)
#  index_notes_on_patient_id          (patient_id)
#  index_notes_on_session_id          (session_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_user_id => users.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (session_id => sessions.id)
#
describe Note do
  subject(:note) { build(:note) }

  describe "associations" do
    it { should belong_to(:created_by).with_foreign_key("created_by_user_id") }
    it { should belong_to(:patient) }
    it { should belong_to(:session) }

    it { should have_one(:team).through(:session) }
  end

  describe "validations" do
    it { should be_valid }

    it { should validate_presence_of(:body) }
    it { should validate_length_of(:body).is_at_most(1000) }
  end

  describe "#programmes" do
    subject(:programmes) { note.programmes }

    let(:note) { create(:note, patient:, session:) }

    let(:patient) { create(:patient, year_group: 8) }
    let(:hpv_programme) { Programme.hpv }
    let(:menacwy_programme) { Programme.menacwy }
    let(:session) do
      create(:session, programmes: [hpv_programme, menacwy_programme])
    end

    it "only show programmes valid for the patient at the time" do
      expect(programmes).to contain_exactly(hpv_programme)
    end
  end
end
