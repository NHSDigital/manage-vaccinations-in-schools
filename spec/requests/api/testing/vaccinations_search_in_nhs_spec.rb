# frozen_string_literal: true

describe "/api/testing/vaccinations-search-in-nhs" do
  before { Flipper.enable(:testing_api) }
  after { Flipper.disable(:testing_api) }

  describe "POST" do
    context "without wait param" do
      it "enqueues the job and responds with accepted" do
        expect {
          post "/api/testing/vaccinations-search-in-nhs"
        }.to have_enqueued_job(EnqueueVaccinationsSearchInNHSJob)
        expect(response).to have_http_status(:accepted)
      end
    end

    context "with wait=true" do
      before do
        allow(EnqueueVaccinationsSearchInNHSJob).to receive(:perform_now)
        allow(Sidekiq::Queue).to receive(:new).with(
          "immunisations_api_search"
        ).and_return(instance_double(Sidekiq::Queue, size: 0))
      end

      it "runs the job synchronously and responds with ok" do
        post "/api/testing/vaccinations-search-in-nhs", params: { wait: "true" }
        expect(EnqueueVaccinationsSearchInNHSJob).to have_received(:perform_now)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
