# frozen_string_literal: true

describe "Location exports" do
  let(:team) { create(:team, :with_one_nurse) }
  let(:nurse) { team.users.first }

  before do
    sign_in nurse
    2.times { follow_redirect! }
  end

  describe "POST /schools/:school_urn_and_site/patients/exports (school context)" do
    let(:school) { create(:gias_school, team:) }

    it "creates a location export and enqueues the job" do
      expect(GenerateExportJob).to receive(:perform_later)

      post school_patients_exports_path(school)

      expect(response).to redirect_to(school_patients_path(school))
      expect(LocationPatientsExport.last).to have_attributes(location: school)
      expect(Export.last).to have_attributes(
        team:,
        user: nurse,
        status: "pending"
      )
    end

    it "stores filter params from the request" do
      post school_patients_exports_path(school, year_groups: [7])

      expect(LocationPatientsExport.last.filter_params).to include(
        "year_groups" => ["7"]
      )
    end
  end

  describe "POST /patients/exports (clinic context)" do
    it "creates a location export and enqueues the job" do
      expect(GenerateExportJob).to receive(:perform_later)

      post patients_clinic_location_exports_path

      expect(response).to redirect_to(patients_path)
      expect(LocationPatientsExport.last).to have_attributes(
        location: team.generic_clinic
      )
      expect(Export.last).to have_attributes(
        team:,
        user: nurse,
        status: "pending"
      )
    end

    it "stores filter params from the request" do
      post patients_clinic_location_exports_path(invited_to_clinic: true)

      expect(LocationPatientsExport.last.filter_params).to include(
        "invited_to_clinic" => "true"
      )
    end
  end

  describe "GET /exports/:id/download" do
    let(:exportable) { create(:location_patients_export) }

    context "when export is ready" do
      let(:export) { create(:export, :ready, exportable:, team:, user: nurse) }

      it "returns the xlsx file" do
        get download_export_path(export)

        expect(response).to have_http_status(:ok)
        expect(response.headers["Content-Type"]).to include(
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
      end
    end

    context "when export is not ready" do
      let(:export) { create(:export, exportable:, team:, user: nurse) }

      it "returns forbidden" do
        get download_export_path(export)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
