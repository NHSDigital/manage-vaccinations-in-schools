# frozen_string_literal: true

describe PatientTeamUpdater do
  shared_examples "updates" do
    context "with an archive reason" do
      before do
        create(:archive_reason, :imported_in_error, patient:, team:)
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly("archive_reason")
      end
    end

    context "with a patient location" do
      before do
        create(:patient_location, patient:, session: create(:session, team:))
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly("patient_location")
      end
    end

    context "with a school move" do
      before do
        create(
          :school_move,
          :to_school,
          patient:,
          school: create(:gias_school, team:)
        )
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly(
          "school_move_school"
        )
      end
    end

    context "with a vaccination record by import" do
      before do
        create(
          :vaccination_record,
          patient:,
          team: nil,
          immunisation_imports: [create(:immunisation_import, team:)]
        )
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly(
          "vaccination_record_import"
        )
      end
    end

    context "with a vaccination record by session" do
      before do
        create(
          :vaccination_record,
          patient:,
          team: nil,
          session: create(:session, team:)
        )
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly(
          "vaccination_record_session"
        )
      end
    end

    context "with multiple sources" do
      before do
        create(:archive_reason, :imported_in_error, patient:, team:)
        create(:patient_location, patient:, session: create(:session, team:))
        PatientTeam.delete_all
      end

      it "adds the patient to the team" do
        expect(patient.teams).to be_empty
        expect { call }.to change(PatientTeam, :count).by(1)
        expect(PatientTeam.last.sources).to contain_exactly(
          "archive_reason",
          "patient_location"
        )
      end
    end

    context "with a previous source that's no longer applicable" do
      before do
        create(:archive_reason, :imported_in_error, patient:, team:)
        PatientTeam.find_by!(patient:, team:).update!(
          sources: %w[patient_location]
        )
      end

      it "adds the patient to the team" do
        expect { call }.not_to change(PatientTeam, :count)
        expect(PatientTeam.last.sources).to contain_exactly("archive_reason")
      end
    end

    context "when previously part of a team" do
      before do
        PatientTeam.create!(patient:, team:, sources: %w[patient_location])
      end

      it "removes the patient from the team" do
        expect { call }.to change(PatientTeam, :count).by(-1)
      end
    end
  end

  context "without scopes" do
    subject(:call) { described_class.call }

    let(:patient) { create(:patient) }
    let(:team) { create(:team) }

    include_examples "updates"
  end

  context "with a patient scope" do
    subject(:call) { described_class.call(patient_scope:) }

    let(:patient) { create(:patient) }
    let(:team) { create(:team) }

    context "and filtering by ID" do
      let(:patient_scope) { Patient.where(id: patient.id) }

      include_examples "updates"
    end

    context "and filtering by a different column" do
      let(:patient_scope) { Patient.where(family_name: patient.family_name) }

      include_examples "updates"
    end
  end

  context "with a team scope" do
    subject(:call) { described_class.call(team_scope:) }

    let(:patient) { create(:patient) }
    let(:team) { create(:team) }

    context "and filtering by ID" do
      let(:team_scope) { Team.where(id: team.id) }

      include_examples "updates"
    end

    context "and filtering by a different column" do
      let(:team_scope) { Team.where(workgroup: team.workgroup) }

      include_examples "updates"
    end
  end
end
