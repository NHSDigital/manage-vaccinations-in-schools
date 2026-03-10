# frozen_string_literal: true

describe PatientStatusUpdater do
  subject(:call) { described_class.call }

  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  let(:session) { create(:session, programmes:) }

  before { create(:patient_location, patient:, session:) }

  context "with an HPV session and ineligible patient" do
    let(:programmes) { [Programme.hpv] }
    let(:patient) { create(:patient, year_group: 7) }

    it "creates a programme status for all programmes" do
      expect { call }.to change(patient.programme_statuses, :count).by(5)
    end

    it "doesn't create any registration statuses" do
      expect { call }.not_to change(Patient::RegistrationStatus, :count)
    end
  end

  context "with an flu session and eligible patient" do
    let(:programmes) { [Programme.flu] }
    let(:patient) { create(:patient, year_group: 8) }

    it "creates a programme status for all programmes" do
      expect { call }.to change(patient.programme_statuses, :count).by(5)
    end

    it "creates a registration status" do
      expect { call }.to change(patient.registration_statuses, :count).by(1)
      expect(patient.registration_statuses.first).to be_unknown
    end
  end

  context "with an HPV session and eligible patient" do
    let(:programmes) { [Programme.hpv] }
    let(:patient) { create(:patient, year_group: 8) }

    it "creates a programme status for all programmes" do
      expect { call }.to change(patient.programme_statuses, :count).by(5)
    end

    it "creates a registration status" do
      expect { call }.to change(patient.registration_statuses, :count).by(1)
      expect(patient.registration_statuses.first).to be_unknown
    end
  end

  context "with a doubles session and ineligible patient" do
    let(:programmes) { [Programme.menacwy, Programme.td_ipv] }
    let(:patient) { create(:patient, year_group: 8) }

    it "creates a programme status for all programmes" do
      expect { call }.to change(patient.programme_statuses, :count).by(5)
    end

    it "doesn't create any registration statuses" do
      expect { call }.not_to change(Patient::RegistrationStatus, :count)
    end
  end

  context "with an doubles session and eligible patient" do
    let(:programmes) { [Programme.menacwy, Programme.td_ipv] }
    let(:patient) { create(:patient, year_group: 9) }

    it "creates a programme status for all programmes" do
      expect { call }.to change(patient.programme_statuses, :count).by(5)
    end

    it "creates a registration status" do
      expect { call }.to change(patient.registration_statuses, :count).by(1)
      expect(patient.registration_statuses.first).to be_unknown
    end
  end
end
