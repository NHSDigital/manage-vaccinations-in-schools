# frozen_string_literal: true

describe PatientsAgedOutOfSchoolJob do
  subject(:perform) { described_class.new.perform(school.id) }

  around { |example| travel_to(today) { example.run } }

  let(:programme) { Programme.flu }
  let(:team) { create(:team, programmes: [programme]) }
  let(:school) { create(:gias_school, :secondary, team:) }

  # This date of birth corresponds to year 11 in 2024/25.
  let(:date_of_birth) { Date.new(2008, 1, 1) }

  let!(:patient) { create(:patient, school:, date_of_birth:) }

  context "on the last day of July" do
    let(:today) { Date.new(2024, 7, 31) }

    it "doesn't create any school moves" do
      expect { perform }.not_to change(SchoolMove, :count)
    end

    it "doesn't create any school moves log entries" do
      expect { perform }.not_to change(SchoolMoveLogEntry, :count)
    end

    it "doesn't move the patient to unknown school" do
      expect { perform }.not_to(change { patient.reload.school })
    end

    it "doesn't add the patient to the clinic session" do
      expect { perform }.not_to(change { patient.sessions.count })
    end
  end

  context "on the first day of August" do
    let(:today) { Date.new(2024, 8, 1) }

    it "doesn't create any school moves" do
      expect { perform }.not_to change(SchoolMove, :count)
    end

    it "creates a school move log entry" do
      expect { perform }.to change(SchoolMoveLogEntry, :count).by(1)

      school_move_log_entry = SchoolMoveLogEntry.first
      expect(school_move_log_entry.patient).to eq(patient)
      expect(school_move_log_entry.school).to eq(team.unknown_school)
    end

    it "moves the patient to unknown school" do
      expect { perform }.to change { patient.reload.school }.to(
        team.unknown_school
      )
    end

    it "adds the patient to the clinic session" do
      expect { perform }.to change { patient.locations.count }.by(1)
      expect(patient.locations).to include(team.unknown_school)
    end
  end
end
