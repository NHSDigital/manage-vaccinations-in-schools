# frozen_string_literal: true

describe "School moves exports" do
  let(:team) { create(:team, :with_one_nurse) }
  let(:nurse) { team.users.first }

  before do
    sign_in nurse
    2.times { follow_redirect! }
  end

  describe "GET /school-moves/exports/new" do
    it "returns 200" do
      get new_school_moves_export_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /school-moves/exports" do
    context "with no dates" do
      it "creates a SchoolMovesExport and enqueues the job" do
        expect(GenerateExportJob).to receive(:perform_later)

        post school_moves_exports_path, params: { school_moves_export_form: {} }

        expect(response).to redirect_to(downloads_path)
        expect(SchoolMovesExport.last).to be_present
        expect(Export.last).to have_attributes(team:, user: nurse)
      end
    end
  end
end
