# frozen_string_literal: true

describe "Patient sessions activity" do
  let(:team) { create(:team, :with_one_nurse) }
  let(:session) { create(:session, team:) }
  let(:patient) { create(:patient, session:) }
  let(:nurse) { team.users.first }

  let(:activity_path) do
    "/sessions/#{session.slug}/patients/#{patient.id}/activity"
  end
  let(:note_path) { "/patients/#{patient.id}/note" }

  before do
    sign_in nurse
    2.times { follow_redirect! }
  end

  it "renders the add note form" do
    get activity_path
    expect(response.body).to include("Add a session note")
  end

  describe "creating notes" do
    it "creates a session note and redirects to the activity log" do
      post note_path,
           params: {
             session_id: session.id,
             note: {
               body: "My note"
             }
           }
      expect(response).to redirect_to(activity_path)

      follow_redirect!
      expect(response.body).to include("Note added")

      note = Note.last
      expect(note.patient).to eq(patient)
      expect(note.session).to eq(session)
      expect(note.created_by).to eq(nurse)
      expect(note.body).to eq("My note")
    end

    it "creates a patient note and redirects to the patient path" do
      post note_path, params: { note: { body: "My note" } }
      expect(response).to redirect_to(patient_path(patient))

      follow_redirect!
      expect(response.body).to include("Note added")

      note = Note.last
      expect(note.patient).to eq(patient)
      expect(note.created_by).to eq(nurse)
      expect(note.body).to eq("My note")
    end

    it "validates the body is present" do
      post note_path, params: { note: { body: "" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter a note")
    end

    it "validates the body isn't too long" do
      post note_path, params: { note: { body: "a" * 2000 } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        "Enter a note that is less than 1000 characters long"
      )
    end
  end
end
