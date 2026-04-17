# frozen_string_literal: true

describe "Vaccination records exports" do
  let(:team) { create(:team, :with_one_nurse, programmes: [Programme.hpv]) }
  let(:nurse) { team.users.first }

  before do
    sign_in nurse
    2.times { follow_redirect! }
  end

  describe "GET /vaccination-records/exports/new" do
    it "returns 200" do
      get new_vaccination_records_export_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /vaccination-records/exports" do
    let(:valid_params) do
      {
        vaccination_records_export_form: {
          academic_year: AcademicYear.current.to_s,
          programme_type: "hpv",
          file_format: "mavis"
        }
      }
    end

    context "with valid params" do
      it "creates a VaccinationRecordsExport and enqueues the job" do
        expect(GenerateExportJob).to receive(:perform_later)

        post vaccination_records_exports_path, params: valid_params

        expect(response).to redirect_to(downloads_path)
        expect(VaccinationRecordsExport.last).to have_attributes(
          programme_type: "hpv",
          file_format: "mavis"
        )
        expect(Export.last).to have_attributes(team:, user: nurse)
      end
    end

    context "with missing programme_type" do
      it "re-renders the form" do
        post vaccination_records_exports_path,
             params: {
               vaccination_records_export_form: {
                 academic_year: AcademicYear.current.to_s,
                 file_format: "mavis"
               }
             }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
