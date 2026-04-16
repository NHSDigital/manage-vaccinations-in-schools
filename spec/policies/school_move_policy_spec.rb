# frozen_string_literal: true

describe SchoolMovePolicy do
  describe SchoolMovePolicy::Scope do
    describe "#resolve" do
      subject { described_class.new(user, SchoolMove).resolve }

      let(:programme) { Programme.sample }
      let(:organisation) { create(:organisation) }

      let(:team) { create(:team, organisation:, programmes: [programme]) }
      let(:other_team) { create(:team, organisation:, programmes: [programme]) }
      let(:user) { create(:user, team:) }

      let(:session) { create(:session, team:, programmes: [programme]) }
      let(:other_session) { create(:session, team:, programmes: [programme]) }

      context "patient belonging to two sessions" do
        let(:patient) { create(:patient) }
        let(:school) { create(:gias_school, team:) }
        let(:school_move) do
          create(:school_move, :to_school, patient:, school:)
        end

        before do
          create(:patient_location, patient:, session:)
          create(:patient_location, patient:, session: other_session)
        end

        it { should contain_exactly(school_move) }
      end

      context "school move with school in different team" do
        let(:patient) { create(:patient) }
        let(:school) { create(:gias_school, team: other_team) }
        let(:school_move) do
          create(:school_move, :to_school, patient:, school:)
        end

        it { should be_empty }
      end
    end
  end
end
