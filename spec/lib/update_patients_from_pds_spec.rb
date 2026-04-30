# frozen_string_literal: true

describe UpdatePatientsFromPDS do
  subject(:call) { described_class.call(patients, queue:) }

  let(:patients) { Patient.order(:created_at) }
  let(:queue) { :pds }

  before do
    create_list(:patient, 2)
    create_list(:patient, 2, nhs_number: nil)
  end

  it "queues no jobs" do
    expect { call }.not_to enqueue_sidekiq_job
  end

  context "when feature is enabled but not main switch" do
    before { Flipper.enable(:pds_enqueue_bulk_updates) }

    it "queues no jobs" do
      expect { call }.not_to enqueue_sidekiq_job
    end
  end

  context "when main switch is enabled but not feature" do
    before { Flipper.enable(:pds) }

    it "queues no jobs" do
      expect { call }.not_to enqueue_sidekiq_job
    end
  end

  context "when main switch and feature is enabled" do
    before do
      Flipper.enable(:pds)
      Flipper.enable(:pds_enqueue_bulk_updates)
    end

    it "queues PDSCascadingSearchJob for patients without an NHS number" do
      expect { call }.to enqueue_sidekiq_job(PDSCascadingSearchJob)
        .on("pds")
        .exactly(2)
        .times
    end

    it "queues a job for each patient with an NHS number" do
      expect { call }.to enqueue_sidekiq_job(PatientUpdateFromPDSJob)
        .on("pds")
        .exactly(2)
        .times
    end
  end
end
