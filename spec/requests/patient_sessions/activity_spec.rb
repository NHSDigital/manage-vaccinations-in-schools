# frozen_string_literal: true

describe "Patient sessions activity" do
  let(:team) { create(:team, :with_one_nurse) }
  let(:session) { create(:session, team:) }
  let(:patient) { create(:patient, session:) }
  let(:nurse) { team.users.first }

  describe "creating notes" do
    let(:path) { "/sessions/#{session.slug}/patients/#{patient.id}/activity" }

    before do
      sign_in nurse
      2.times { follow_redirect! }
    end

    it "renders the add note form" do
      get path
      expect(response.body).to include("Add a session note")
    end

    it "creates a note and redirects to the activity log" do
      post path, params: { note: { body: "My note" } }
      expect(response).to redirect_to(path)

      follow_redirect!
      expect(response.body).to include("Note added")

      note = Note.last
      expect(note.patient).to eq(patient)
      expect(note.session).to eq(session)
      expect(note.created_by).to eq(nurse)
      expect(note.body).to eq("My note")
    end

    it "validates the body is present" do
      post path, params: { note: { body: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter a note")
    end

    it "validates the body isn't too long" do
      post path, params: { note: { body: "a" * 2000 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        "Enter a note that is less than 1000 characters long"
      )
    end
  end
end
