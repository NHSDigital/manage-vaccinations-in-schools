# frozen_string_literal: true

describe EnqueueProcessUnmatchedConsentFormsJob do
  subject(:perform) { described_class.new.perform }

  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:session) { create(:session, team:, programmes: [programme]) }

  let!(:unmatched_consent_form) { create(:consent_form, :recorded, session:) }
  let!(:draft_consent_form) { create(:consent_form, :draft, session:) }
  let!(:archived_consent_form) do
    create(
      :consent_form,
      :recorded,
      :archived,
      session:,
      notes: "Archived consent form"
    )
  end

  it "enqueues a job for each unmatched consent form" do
    expect { perform }.to enqueue_sidekiq_job(ProcessConsentFormJob).exactly(
      1
    ).times
  end

  it "enqueues a job for the unmatched consent form" do
    expect { perform }.to enqueue_sidekiq_job(ProcessConsentFormJob).with(
      unmatched_consent_form.id
    )
  end

  it "does not enqueue a job for the draft consent form" do
    expect { perform }.not_to enqueue_sidekiq_job(ProcessConsentFormJob).with(
      draft_consent_form.id
    )
  end

  it "does not enqueue a job for the archived consent form" do
    expect { perform }.not_to enqueue_sidekiq_job(ProcessConsentFormJob).with(
      archived_consent_form.id
    )
  end
end
