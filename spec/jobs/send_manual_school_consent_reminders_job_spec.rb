# frozen_string_literal: true

describe SendManualSchoolConsentRemindersJob do
  subject(:perform) do
    PatientStatusUpdater.call
    described_class.new.perform(session.id, user.id)
  end

  let(:programmes) { [Programme.flu] }

  let(:request_notification) do
    create(
      :consent_notification,
      patient:,
      session:,
      programmes:,
      type: :request,
      sent_at: dates.first - 2.weeks
    )
  end
  let(:today) { dates.first - 1.week }
  let(:team) { create(:team, programmes:) }
  let(:location) { create(:gias_school, team:) }
  let(:parents) { create_list(:parent, 2) }
  let(:patient) { create(:patient, team:, parents:) }
  let(:user) { create(:user, team:) }

  let(:dates) { [Date.new(2024, 1, 12), Date.new(2024, 1, 15)] }

  let!(:session) do
    create(
      :session,
      dates:,
      send_consent_requests_at: dates.first - 3.weeks,
      days_before_consent_reminders: 7,
      location:,
      programmes:,
      team:
    )
  end

  let(:parent) { create(:parent) }

  before do
    create(:parent_relationship, patient:, parent:)
    create(:patient_location, patient:, session:)
    patient.reload
  end

  around { |example| travel_to(today) { example.run } }

  context "when the patient has not consented or been vaccinated" do
    it "creates a notification" do
      expect { perform }.to change(ConsentNotification, :count).by(1)

      last_notification = ConsentNotification.last
      expect(last_notification.patient).to eq(patient)
      expect(last_notification.programmes).to match_array(programmes)
      expect(last_notification.automated_reminder?).to be false
      expect(last_notification.sent_by).to eq(user)
    end
  end

  context "when the patient has already replied to the consent form" do
    before do
      create(
        :consent,
        patient:,
        programme: programmes.first,
        submitted_at: today
      )
    end

    it "does not create a notification" do
      expect { perform }.not_to change(ConsentNotification, :count)
    end
  end

  context "when the patient has already been vaccinated" do
    before do
      create(
        :vaccination_record,
        patient:,
        programme: programmes.first,
        performed_at: today
      )
    end

    it "does not create a notification" do
      expect { perform }.not_to change(ConsentNotification, :count)
    end
  end

  context "if the patient is deceased" do
    let(:patient) { create(:patient, :deceased, parents:) }

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform
    end
  end

  context "if the patient is invalid" do
    let(:patient) { create(:patient, :invalidated, parents:) }

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform
    end
  end

  context "if the patient is restricted" do
    let(:patient) { create(:patient, :restricted, parents:) }

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform
    end
  end

  context "if the patient is archived" do
    let(:patient) { create(:patient, :archived, parents:, team:) }

    it "doesn't send any notifications" do
      expect(SessionNotification).not_to receive(:create_and_send!)
      perform
    end
  end
end
