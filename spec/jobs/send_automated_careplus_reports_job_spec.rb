# frozen_string_literal: true

describe SendAutomatedCareplusReportsJob do
  describe "#perform" do
    it "delegates to Careplus::AutomatedReportSender" do
      team = create(:team, :with_careplus_enabled, programmes: Programme.all)

      expect(Careplus::AutomatedReportSender).to receive(:call).with(
        team_id: team.id
      )

      described_class.new.perform(team.id)
    end
  end
end
