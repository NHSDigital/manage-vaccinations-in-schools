# frozen_string_literal: true

describe "/api/testing/vaccinations-search-in-nhs" do
  before { Flipper.enable(:testing_api) }

  describe "POST" do
    context "without wait param" do
      it "enqueues the job and responds with accepted" do
        expect {
          post "/api/testing/vaccinations-search-in-nhs"
        }.to enqueue_sidekiq_job(EnqueueVaccinationsSearchInNHSJob)
        expect(response).to have_http_status(:accepted)
      end
    end

    context "with wait=true" do
      let(:job_double) { instance_double(EnqueueVaccinationsSearchInNHSJob) }

      before do
        allow(EnqueueVaccinationsSearchInNHSJob).to receive(:new).and_return(
          job_double
        )
        allow(job_double).to receive(:perform)
        allow(Sidekiq::Queue).to receive(:new).with(
          "immunisations_api_search"
        ).and_return(instance_double(Sidekiq::Queue, size: 0))
      end

      it "runs the job synchronously and responds with ok" do
        expect {
          post "/api/testing/vaccinations-search-in-nhs",
               params: {
                 wait: "true"
               }
        }.not_to enqueue_sidekiq_job

        expect(job_double).to have_received(:perform)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
