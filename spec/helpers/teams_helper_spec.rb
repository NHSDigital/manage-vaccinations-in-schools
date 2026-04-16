# frozen_string_literal: true

describe TeamsHelper do
  let(:team) do
    create(
      :team,
      name: "SAIS Team",
      email: "sais@example.com",
      phone: "01234 567890"
    )
  end

  let(:session) { create(:session, team:) }

  context "with a session" do
    describe "#team_contact_name" do
      subject { helper.team_contact_name(session:) }

      context "without a subteam" do
        it { should eq("SAIS Team") }
      end

      context "with a subteam" do
        before do
          subteam = create(:subteam, team:, name: "SAIS Subteam")
          session.team_location.update!(subteam:)
        end

        it { should eq("SAIS Subteam") }
      end
    end

    describe "#team_contact_email" do
      subject { helper.team_contact_email(session:) }

      context "without a subteam" do
        it { should eq("sais@example.com") }
      end

      context "with a subteam" do
        before do
          subteam = create(:subteam, team:, email: "subteam@example.com")
          session.team_location.update!(subteam:)
        end

        it { should eq("subteam@example.com") }
      end
    end

    describe "#team_contact_phone" do
      subject { helper.team_contact_phone(session:) }

      context "without a subteam" do
        it { should eq("01234 567890") }
      end

      context "with a subteam" do
        before do
          subteam =
            create(
              :subteam,
              team:,
              phone: "01234 567890",
              phone_instructions: "option 2"
            )
          session.team_location.update!(subteam:)
        end

        it { should eq("01234 567890 (option 2)") }
      end
    end
  end

  context "with neither session nor vaccination_record" do
    it "raises an ArgumentError" do
      expect { helper.team_contact_name }.to raise_error(ArgumentError)
    end
  end

  context "with both session and vaccination_record" do
    let(:vaccination_record) do
      create(:vaccination_record, programme: Programme.hpv, session:)
    end

    it "raises an ArgumentError" do
      expect {
        helper.team_contact_name(session:, vaccination_record:)
      }.to raise_error(ArgumentError)
    end
  end

  context "with a vaccination_record without a session" do
    let(:school) { create(:gias_school, team:) }
    let(:patient) { create(:patient, school:) }
    let(:vaccination_record) do
      create(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        patient:,
        session: nil
      )
    end

    describe "#team_contact_name" do
      subject { helper.team_contact_name(vaccination_record:) }

      it { should eq("SAIS Team") }
    end

    describe "#team_contact_email" do
      subject { helper.team_contact_email(vaccination_record:) }

      it { should eq("sais@example.com") }
    end

    describe "#team_contact_phone" do
      subject { helper.team_contact_phone(vaccination_record:) }

      it { should eq("01234 567890") }
    end
  end
end
