# frozen_string_literal: true

describe EnqueueSchoolSessionRemindersJob do
  subject(:perform) { described_class.new.perform }

  context "with a session from last week" do
    let(:session) { create(:session, :completed) }

    it "doesn't queue a job" do
      expect { perform }.not_to enqueue_sidekiq_job(
        SendSchoolSessionRemindersSidekiqJob
      )
    end
  end

  context "with a session today" do
    let(:session) { create(:session, :today) }

    it "doesn't queue a job" do
      expect { perform }.not_to enqueue_sidekiq_job(
        SendSchoolSessionRemindersSidekiqJob
      )
    end
  end

  context "with a session tomorrow" do
    let(:session) { create(:session, :tomorrow) }

    it "queues a job" do
      expect { perform }.to enqueue_sidekiq_job(
        SendSchoolSessionRemindersSidekiqJob
      ).with(session.id)
    end
  end

  context "with a session next week" do
    let(:session) { create(:session, :scheduled) }

    it "doesn't queue a job" do
      expect { perform }.not_to enqueue_sidekiq_job(
        SendSchoolSessionRemindersSidekiqJob
      )
    end
  end
end
