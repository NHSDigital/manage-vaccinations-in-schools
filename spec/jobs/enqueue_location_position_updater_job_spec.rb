# frozen_string_literal: true

describe EnqueueLocationPositionUpdaterJob do
  subject(:perform) { described_class.new.perform }

  let!(:location_with_address_no_position) do
    create(:community_clinic, position: nil)
  end

  let!(:location_with_position) { create(:community_clinic) }

  let!(:location_without_address) do
    create(:community_clinic, :without_address)
  end

  it "enqueues jobs for locations with address but no position" do
    expect { perform }.to enqueue_sidekiq_job(LocationPositionUpdaterJob).with(
      location_with_address_no_position.id
    )
  end

  it "does not enqueue jobs for locations with position" do
    expect { perform }.not_to enqueue_sidekiq_job(
      LocationPositionUpdaterJob
    ).with(location_with_position.id)
  end

  it "does not enqueue jobs for locations without address" do
    expect { perform }.not_to enqueue_sidekiq_job(
      LocationPositionUpdaterJob
    ).with(location_without_address.id)
  end
end
