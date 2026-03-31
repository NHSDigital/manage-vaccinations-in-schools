# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis teams merge" do
  let(:organisation) { create(:organisation) }

  let!(:team_a) do
    create(
      :team,
      organisation:,
      workgroup: "team-a",
      name: "Team A",
      programmes: [Programme.hpv]
    )
  end

  let!(:team_b) do
    create(
      :team,
      organisation:,
      workgroup: "team-b",
      name: "Team B",
      programmes: [Programme.flu]
    )
  end

  before do
    create(:generic_clinic, team: team_a)
    create(:generic_clinic, team: team_b)
  end

  def merge_command(**overrides)
    defaults = {
      workgroups: %w[team-a team-b],
      name: "Team Combined",
      workgroup: "team-combined"
    }
    opts = defaults.merge(overrides)
    args = [
      "teams",
      "merge",
      *opts[:workgroups],
      "--name=#{opts[:name]}",
      "--workgroup=#{opts[:workgroup]}",
      "--email=combined@example.com",
      "--phone=01234 567890",
      "--privacy-notice-url=https://example.com/privacy-notice",
      "--privacy-policy-url=https://example.com/privacy-policy"
    ]
    args << "--dry-run" if opts[:dry_run]
    Dry::CLI.new(MavisCLI).call(arguments: args)
  end

  context "happy path — two compatible teams" do
    it "creates merged team, migrates records, and deletes source teams" do
      consent = create(:consent, team: team_a)
      cohort_import = create(:cohort_import, team: team_b)

      capture_output { merge_command }

      expect(Team.find_by(workgroup: "team-combined")).to be_present
      expect(Team.find_by(workgroup: "team-a")).to be_nil
      expect(Team.find_by(workgroup: "team-b")).to be_nil

      merged = Team.find_by(workgroup: "team-combined")
      expect(merged.programme_types).to match_array(%w[flu hpv])

      expect(consent.reload.team).to eq(merged)
      expect(cohort_import.reload.team).to eq(merged)
    end
  end

  context "with --dry-run" do
    it "prints the migration plan and makes no DB changes" do
      create(:consent, team: team_a)

      output = capture_output { merge_command(dry_run: true) }

      expect(output).to include("consents: 1 row(s) to migrate")
      expect(output).to include("Merge would succeed.")

      expect(Team.find_by(workgroup: "team-a")).to be_present
      expect(Team.find_by(workgroup: "team-b")).to be_present
      expect(Team.find_by(workgroup: "team-combined")).to be_nil
    end
  end
end
