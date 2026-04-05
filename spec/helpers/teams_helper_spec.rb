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

  describe "#team_contact_name" do
    subject { helper.team_contact_name(session) }

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
    subject { helper.team_contact_email(session) }

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
    subject { helper.team_contact_phone(session) }

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
