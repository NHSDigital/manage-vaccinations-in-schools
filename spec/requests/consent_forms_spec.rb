# frozen_string_literal: true

describe "Consent forms" do
  let(:team) { create(:team) }
  let(:nurse) { create(:nurse, teams: [team]) }

  describe "downloading paper version" do
    let(:path) { "/consent-form/mmr" }

    before do
      sign_in nurse
      2.times { follow_redirect! }
    end

    it "downloads a PDF file with a suitable filename" do
      get path
      expect(response.headers["Content-Type"]).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include(
        "filename=\"MMR Consent Form.pdf\""
      )
    end
  end
end
