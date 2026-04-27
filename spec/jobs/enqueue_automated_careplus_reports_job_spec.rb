# frozen_string_literal: true

describe EnqueueAutomatedCareplusReportsJob do
  subject(:perform) { described_class.new.perform }

  let(:eligible_team) do
    create(:team, :with_careplus_enabled, programmes: Programme.all)
  end
  let(:team_without_credentials) do
    create(
      :team,
      :with_careplus_enabled,
      careplus_username: nil,
      programmes: Programme.all
    )
  end
  let(:team_without_careplus_report_fields) do
    create(
      :team,
      careplus_username: "careplus_user",
      careplus_password: "careplus_password",
      careplus_namespace: "MOCK",
      programmes: Programme.all
    )
  end

  it "enqueues a send job for each team with CarePlus enabled and credentials configured" do
    eligible_team
    team_without_credentials
    team_without_careplus_report_fields

    expect { perform }.to enqueue_sidekiq_job(
      SendAutomatedCareplusReportsJob
    ).once.with(eligible_team.id)
  end
end
