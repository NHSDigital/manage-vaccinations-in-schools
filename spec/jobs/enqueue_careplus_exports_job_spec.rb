# frozen_string_literal: true

describe EnqueueCareplusExportsJob do
  subject(:perform_now) { described_class.perform_now }

  context "when no teams exist" do
    it "does not enqueue any jobs" do
      expect { perform_now }.not_to have_enqueued_job(SendCareplusExportJob)
    end
  end

  context "when a team has careplus_enabled? but missing credentials" do
    before do
      create(
        :team,
        :with_careplus_enabled,
        careplus_username: nil,
        careplus_password: nil
      )
    end

    it "does not enqueue a job for that team" do
      expect { perform_now }.not_to have_enqueued_job(SendCareplusExportJob)
    end
  end

  context "when a team has careplus_enabled? but missing namespace" do
    before { create(:team, :with_careplus_enabled, careplus_namespace: nil) }

    it "does not enqueue a job for that team" do
      expect { perform_now }.not_to have_enqueued_job(SendCareplusExportJob)
    end
  end

  context "when a team has careplus_enabled? but is missing venue config" do
    before do
      create(:team, careplus_username: "user", careplus_password: "pass")
    end

    it "does not enqueue a job for that team" do
      expect { perform_now }.not_to have_enqueued_job(SendCareplusExportJob)
    end
  end

  context "when a team has full careplus configuration" do
    let!(:team) { create(:team, :with_careplus_enabled) }

    it "enqueues a SendCareplusExportJob for that team" do
      expect { perform_now }.to have_enqueued_job(SendCareplusExportJob).with(
        team.id
      )
    end
  end

  context "when some teams qualify and others do not" do
    let!(:team_with_careplus) { create(:team, :with_careplus_enabled) }
    let!(:team_without_careplus) { create(:team) }

    it "only enqueues jobs for qualifying teams" do
      expect { perform_now }.to have_enqueued_job(SendCareplusExportJob).with(
        team_with_careplus.id
      )
    end

    it "does not enqueue jobs for unconfigured teams" do
      expect { perform_now }.not_to have_enqueued_job(
        SendCareplusExportJob
      ).with(team_without_careplus.id)
    end
  end
end
