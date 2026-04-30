# frozen_string_literal: true

describe "/api/testing/refresh-reporting" do
  before { Flipper.enable(:testing_api) }

  describe "GET" do
    context "without wait param" do
      it "enqueues the job and responds with accepted" do
        expect { get "/api/testing/refresh-reporting" }.to enqueue_sidekiq_job(
          ReportingAPI::RefreshJob
        )
        expect(response).to have_http_status(:accepted)
      end
    end

    context "with wait=true" do
      let(:job_double) { instance_double(ReportingAPI::RefreshJob) }

      before do
        allow(ReportingAPI::RefreshJob).to receive(:new).and_return(job_double)
        allow(job_double).to receive(:perform)
      end

      it "runs the refresh synchronously and responds with ok status" do
        expect {
          get "/api/testing/refresh-reporting", params: { wait: "true" }
        }.not_to enqueue_sidekiq_job
        expect(response).to have_http_status(:ok)
        expect(job_double).to have_received(:perform)
      end
    end
  end
end
