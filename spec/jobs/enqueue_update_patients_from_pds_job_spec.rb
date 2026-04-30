# frozen_string_literal: true

describe EnqueueUpdatePatientsFromPDSJob do
  subject(:perform) { described_class.new.perform }

  let!(:invalidated_patient) { create(:patient, :invalidated) }
  let!(:deceased_patient) { create(:patient, :deceased) }
  let!(:restricted_patient) { create(:patient, :restricted) }
  let!(:recently_updated_patient) do
    create(:patient, updated_from_pds_at: Time.current)
  end
  let!(:not_recently_updated_patient) do
    create(:patient, updated_from_pds_at: 3.days.ago)
  end
  let!(:never_updated_patient) { create(:patient, updated_from_pds_at: nil) }

  before do
    Flipper.enable(:pds)
    Flipper.enable(:pds_enqueue_bulk_updates)
  end

  it "only queues jobs for the appropriate patients" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).exactly(4).times
  end

  it "queues a job for the invalidated patient" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(invalidated_patient.id, nil)
  end

  it "doesn't queue a job for the deceased patient" do
    expect { perform }.not_to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(deceased_patient.id, nil)
  end

  it "doesn't queue a job for the recently updated patient" do
    expect { perform }.not_to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(recently_updated_patient.id, nil)
  end

  it "queues a job for the restricted patient" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(restricted_patient.id, nil)
  end

  it "queues a job for the not recently updated patient" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(not_recently_updated_patient.id, nil)
  end

  it "queues a job for the never updated patient" do
    expect { perform }.to enqueue_sidekiq_job(
      PatientUpdateFromPDSSidekiqJob
    ).with(never_updated_patient.id, nil)
  end
end
