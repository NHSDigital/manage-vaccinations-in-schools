# frozen_string_literal: true

describe MavisCLI::Teams::SetNationalReportingCutOffDate do
  describe "#call" do
    subject(:command) do
      capture_output do
        described_class.new.call(workgroup: team.workgroup, date: date, clear:)
      end
    end

    let(:date) { "2026-02-01" }
    let(:clear) { false }

    let(:cut_off_date) { Date.new(2026, 2, 1) }

    let(:team) do
      create(
        :team,
        :national_reporting,
        workgroup: "NR-001",
        national_reporting_cut_off_date: nil
      )
    end

    it "sets the cut-off date" do
      expect { command }.to change {
        team.reload.national_reporting_cut_off_date
      }.from(nil).to(cut_off_date)
    end

    context "when clearing the cut-off date" do
      let(:clear) { true }
      let(:date) { nil }
      let(:team) do
        create(
          :team,
          :national_reporting,
          workgroup: "NR-002",
          national_reporting_cut_off_date: cut_off_date
        )
      end

      it "clears the cut-off date" do
        expect { command }.to change {
          team.reload.national_reporting_cut_off_date
        }.from(cut_off_date).to(nil)
      end
    end

    context "when both --date and --clear are provided" do
      let(:clear) { true }

      it "raises" do
        expect { command }.to raise_error(
          ArgumentError,
          /either --date or --clear/i
        )
      end
    end

    context "for a non-national reporting team" do
      let(:team) { create(:team, workgroup: "POC-001") }

      it "raises" do
        expect { command }.to raise_error(
          ArgumentError,
          /not a national reporting team/
        )
      end
    end
  end
end
