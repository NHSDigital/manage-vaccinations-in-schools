# frozen_string_literal: true

describe SessionPolicy do
  subject(:policy) { described_class.new(user, session) }

  shared_examples "edit/update session" do
    context "with a medical secretary" do
      let(:user) { create(:medical_secretary) }

      context "with a scheduled session" do
        let(:session) { create(:session, :scheduled) }

        it { should be(true) }
      end

      context "with an unscheduled session" do
        let(:session) { create(:session, :unscheduled) }

        it { should be(true) }
      end
    end

    context "with a nurse" do
      let(:user) { create(:nurse) }

      context "with a scheduled session" do
        let(:session) { create(:session, :scheduled) }

        it { should be(true) }
      end

      context "with an unscheduled session" do
        let(:session) { create(:session, :unscheduled) }

        it { should be(true) }
      end
    end

    context "with a healthcare assistant" do
      let(:user) { create(:healthcare_assistant) }

      context "with a scheduled session" do
        let(:session) { create(:session, :scheduled) }

        it { should be(true) }
      end

      context "with an unscheduled session" do
        let(:session) { create(:session, :unscheduled) }

        it { should be(true) }
      end
    end

    context "with a prescriber" do
      let(:user) { create(:prescriber) }

      context "with a scheduled session" do
        let(:session) { create(:session, :scheduled) }

        it { should be(true) }
      end

      context "with an unscheduled session" do
        let(:session) { create(:session, :unscheduled) }

        it { should be(true) }
      end
    end
  end

  describe "#edit?" do
    subject(:edit?) { policy.edit? }

    include_examples "edit/update session"
  end

  describe "#update?" do
    subject(:update?) { policy.update? }

    include_examples "edit/update session"
  end

  describe "#cancel?" do
    subject(:cancel?) { policy.cancel? }

    let(:user) { create(:nurse) }

    context "when feature flag is disabled" do
      before { Flipper.disable(:clinic_sessions) }

      let(:session) do
        create(:session, :scheduled, location: create(:community_clinic))
      end

      it { should be(false) }
    end

    context "when feature flag is enabled" do
      before { Flipper.enable(:clinic_sessions) }
      after { Flipper.disable(:clinic_sessions) }

      context "with a future community clinic session" do
        let(:session) do
          create(:session, :scheduled, location: create(:community_clinic))
        end

        it { should be(true) }
      end

      context "with a future generic clinic session" do
        let(:session) do
          create(:session, :scheduled, location: create(:generic_clinic))
        end

        it { should be(true) }
      end

      context "with a school session" do
        let(:session) { create(:session, :scheduled) }

        it { should be(false) }
      end

      context "with a started community clinic session" do
        let(:session) do
          create(:session, :today, location: create(:community_clinic))
        end

        it { should be(false) }
      end

      context "with a completed community clinic session" do
        let(:session) do
          create(:session, :completed, location: create(:community_clinic))
        end

        it { should be(false) }
      end

      context "with a cancelled community clinic session" do
        let(:session) do
          create(
            :session,
            :scheduled,
            :cancelled,
            location: create(:community_clinic)
          )
        end

        it { should be(false) }
      end
    end
  end

  describe SessionPolicy::Scope do
    describe "#resolve" do
      subject { described_class.new(user, Session).resolve }

      let(:user) { create(:user, team:) }

      let(:programme) { Programme.hpv }

      let(:users_teams_session) { create(:session, team:, programmes:) }
      let(:another_teams_session) { create(:session, programmes:) }

      let(:programmes) { [programme] }
      let(:team) { create(:team, programmes:) }

      context "with a session part of the user's teams" do
        let(:session) { create(:session, team:, programmes:) }

        context "and an admin user" do
          let(:user) { create(:medical_secretary, team:) }

          it { should include(session) }
        end

        context "and a nurse user" do
          let(:user) { create(:nurse, team:) }

          it { should include(session) }
        end

        context "and a healthcare assistant user" do
          let(:user) { create(:healthcare_assistant, team:) }

          it { should include(session) }
        end
      end

      context "with a session not part of the user's teams" do
        let(:session) { create(:session, programmes:) }
        let(:user) { create(:user, team:) }

        it { should_not include(session) }
      end
    end
  end
end
