# frozen_string_literal: true

describe PatientArchiver do
  subject(:call) do
    described_class.call(patient:, team:, type:, other_details:)
  end

  let(:patient) { create(:patient) }
  let(:team) { create(:team) }

  let(:type) { "imported_in_error" }
  let(:other_details) { nil }

  it "creates an archive reason" do
    expect { call }.to change(patient.archive_reasons, :count).by(1)

    archive_reason = patient.archive_reasons.last
    expect(archive_reason).to be_imported_in_error
    expect(archive_reason.team_id).to eq(team.id)
  end

  context "when in upcoming sessions" do
    let(:session) { create(:session, :tomorrow, team:) }
    let(:patient) { create(:patient, session:) }

    it "removes the patient from the sessions" do
      expect(patient.sessions).to include(session)
      call
      expect(patient.reload.sessions).not_to include(session)
    end
  end

  context "with a school move for the same team" do
    let!(:school_move) do
      create(:school_move, :to_home_educated, patient:, team:)
    end

    it "deletes the school move" do
      expect { call }.to change(SchoolMove, :count).by(-1)
      expect { school_move.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "with a school move for a school in the same team" do
    let!(:school_move) do
      create(
        :school_move,
        :to_school,
        patient:,
        school: create(:gias_school, team:)
      )
    end

    it "deletes the school move" do
      expect { call }.to change(SchoolMove, :count).by(-1)
      expect { school_move.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "with a school move for an unrelated team" do
    before { create(:school_move, :to_unknown_school, patient:) }

    it "doesn't delete the school move" do
      expect { call }.not_to change(SchoolMove, :count)
    end
  end

  context "with a school move for an unrelated school" do
    before { create(:school_move, :to_school, patient:) }

    it "doesn't delete the school move" do
      expect { call }.not_to change(SchoolMove, :count)
    end
  end

  context "with an other type" do
    let(:type) { "other" }
    let(:other_details) { "Details" }

    it "creates an archive reason" do
      expect { call }.to change(patient.archive_reasons, :count).by(1)

      archive_reason = patient.archive_reasons.last
      expect(archive_reason).to be_other
      expect(archive_reason.team_id).to eq(team.id)
      expect(archive_reason.other_details).to eq("Details")
    end
  end
end
