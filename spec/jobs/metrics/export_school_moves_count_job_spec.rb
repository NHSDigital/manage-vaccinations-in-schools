# frozen_string_literal: true

describe Metrics::ExportSchoolMovesCountJob do
  subject(:perform) { described_class.new.perform }

  let(:client) { instance_double(Aws::CloudWatch::Client) }
  let!(:team_a) { create(:team, workgroup: "abc") }
  let!(:team_b) { create(:team, workgroup: "def") }

  before do
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(client)
    allow(client).to receive(:put_metric_data).with(
      namespace: "Mavis",
      metric_data: anything
    )
  end

  context "with no school moves" do
    it "puts data with counts of zero" do
      expect(client).to receive(:put_metric_data).with(
        namespace: "Mavis",
        metric_data: [
          {
            dimensions: [
              { name: "TeamWorkgroup", value: "abc" },
              { name: "AppEnvironment", value: "development" }
            ],
            metric_name: "SchoolMovesCount",
            unit: "Count",
            value: 0
          },
          {
            dimensions: [
              { name: "TeamWorkgroup", value: "def" },
              { name: "AppEnvironment", value: "development" }
            ],
            metric_name: "SchoolMovesCount",
            unit: "Count",
            value: 0
          }
        ]
      )

      perform
    end
  end

  context "with unresolved school moves" do
    let(:school_a) { create(:school, team: team_a) }
    let(:school_b) { create(:school, team: team_b) }

    before do
      create_list(:school_move, 2, school: school_a)
      create_list(:school_move, 4, school: school_b)
    end

    it "puts data with count values" do
      expect(client).to receive(:put_metric_data).with(
        namespace: "Mavis",
        metric_data: [
          {
            dimensions: [
              { name: "TeamWorkgroup", value: "abc" },
              { name: "AppEnvironment", value: "development" }
            ],
            metric_name: "SchoolMovesCount",
            unit: "Count",
            value: 2
          },
          {
            dimensions: [
              { name: "TeamWorkgroup", value: "def" },
              { name: "AppEnvironment", value: "development" }
            ],
            metric_name: "SchoolMovesCount",
            unit: "Count",
            value: 4
          }
        ]
      )

      perform
    end
  end
end
