# frozen_string_literal: true

describe EnqueuePatientsAgedOutOfSchoolsJob do
  subject(:perform) { described_class.new.perform }

  let!(:school_with_team) { create(:gias_school, team: create(:team)) }

  before { create(:gias_school) }

  it "queues jobs for the schools with teams" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientsAgedOutOfSchoolJob
    ).once.with(school_with_team.id)
  end
end
