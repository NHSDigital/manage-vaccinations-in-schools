# frozen_string_literal: true

describe "Offline session exports" do
  let(:programme) { Programme.hpv }
  let(:team) { create(:team, :with_one_nurse, programmes: [programme]) }
  let(:nurse) { team.users.first }
  let(:location) { create(:gias_school, team:, programmes: [programme]) }
  let(:session) { create(:session, team:, location:, programmes: [programme]) }

  before do
    sign_in nurse
    2.times { follow_redirect! }
  end

  describe "POST /sessions/:session_slug/exports" do
    it "creates a SessionPatientsExport and redirects to the session page" do
      expect { post "/sessions/#{session.slug}/exports" }.to change(
        SessionPatientsExport,
        :count
      ).by(1)

      expect(response).to redirect_to("/sessions/#{session.slug}")
    end

    it "sets a flash success message with a link to Downloads" do
      post "/sessions/#{session.slug}/exports"
      expect(flash[:success]).to include(heading_link_href: "/downloads")
    end

    it "enqueues a GenerateExportJob" do
      expect { post "/sessions/#{session.slug}/exports" }.to have_enqueued_job(
        GenerateExportJob
      )
    end

    it "associates the export with the current user" do
      post "/sessions/#{session.slug}/exports"

      expect(Export.last.user).to eq(nurse)
    end

    it "associates the export with the session" do
      post "/sessions/#{session.slug}/exports"

      export = SessionPatientsExport.last
      expect(export.session).to eq(session)
    end
  end

  describe "GET /exports/:id/download" do
    let(:xlsx_content) { "PK fake xlsx binary" }
    let(:exportable) { create(:session_patients_export, session:) }

    context "when export is ready" do
      let(:export) do
        create(
          :export,
          :ready,
          exportable:,
          team:,
          user: nurse,
          file_data: xlsx_content
        )
      end

      it "sends the XLSX data as a file download" do
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
