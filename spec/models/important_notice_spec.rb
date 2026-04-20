# frozen_string_literal: true

# == Schema Information
#
# Table name: important_notices
#
#  id                       :bigint           not null, primary key
#  dismissed_at             :datetime
#  recorded_at              :datetime         not null
#  type                     :integer          not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  dismissed_by_user_id     :bigint
#  patient_id               :bigint           not null
#  school_move_log_entry_id :bigint
#  team_id                  :bigint           not null
#  vaccination_record_id    :bigint
#
# Indexes
#
#  index_important_notices_on_dismissed_by_user_id             (dismissed_by_user_id)
#  index_important_notices_on_patient_id                       (patient_id)
#  index_important_notices_on_school_move_log_entry_id         (school_move_log_entry_id)
#  index_important_notices_on_team_id                          (team_id)
#  index_important_notices_on_vaccination_record_id            (vaccination_record_id)
#  index_notices_on_patient_and_type_and_recorded_at_and_team  (patient_id,type,recorded_at,team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (dismissed_by_user_id => users.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_move_log_entry_id => school_move_log_entries.id)
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (vaccination_record_id => vaccination_records.id)
#
describe ImportantNotice do
  subject(:notice) { build(:important_notice) }

  let(:team) { create(:team) }
  let(:patient) { create(:patient) }
  let(:user) { create(:user) }

  describe "validations" do
    it { should validate_presence_of(:type) }
    it { should validate_presence_of(:recorded_at) }
  end

  describe "associations" do
    it { should belong_to(:patient) }
  end

  describe "enums" do
    it do
      expect(notice).to define_enum_for(:type).with_values(
        deceased: 0,
        invalidated: 1,
        restricted: 2,
        gillick_no_notify: 3,
        team_changed: 4
      )
    end
  end

  describe "#dismiss!" do
    let(:notice) { create(:important_notice, team_id: team.id) }

    context "when dismissing without a user" do
      it "sets dismissed_at" do
        freeze_time do
          notice.dismiss!
          expect(notice.dismissed_at).to eq(Time.current)
        end
      end

      it "does not set dismissed_by_user_id" do
        notice.dismiss!
        expect(notice.dismissed_by_user_id).to be_nil
      end
    end

    context "when dismissing with a user" do
      it "sets dismissed_at and dismissed_by_user_id" do
        freeze_time do
          notice.dismiss!(user: user)
          expect(notice.dismissed_at).to eq(Time.current)
          expect(notice.dismissed_by_user_id).to eq(user.id)
        end
      end
    end
  end

  describe "#can_dismiss?" do
    subject(:can_dismiss) { important_notice.can_dismiss? }

    let(:important_notice) do
      create(:important_notice, :invalidated, team_id: team.id, patient:)
    end

    context "important notices for invalidated patients cannot be dismissed" do
      it { should be(false) }
    end

    context "important notices for invalidated patients can be dismissed when archived" do
      before { create(:archive_reason, :moved_out_of_area, team:, patient:) }

      it { should be(true) }
    end
  end
end
