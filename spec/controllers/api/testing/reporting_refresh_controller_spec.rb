# frozen_string_literal: true

describe API::Testing::ReportingRefreshController do
  describe "#create" do
    it "performs the refresh job and responds with accepted status" do
      expect(ReportingAPI::RefreshJob).to receive(:perform_later)
      get :create
      expect(response).to have_http_status(:accepted)
    end

    context "when wait=true" do
      it "runs the refresh synchronously and responds with ok status" do
        expect(ReportingAPI::RefreshJob).to receive(:perform_now)
        expect(ReportingAPI::RefreshJob).not_to receive(:perform_later)
        get :create, params: { wait: "true" }
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
