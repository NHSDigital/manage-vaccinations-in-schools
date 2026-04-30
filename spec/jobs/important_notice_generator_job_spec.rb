# frozen_string_literal: true

describe ImportantNoticeGeneratorJob do
  subject(:perform) { described_class.new.perform([patient.id]) }

  let(:team_a) { create(:team) }
  let(:team_b) { create(:team) }
  let(:session_a) { create(:session, team: team_a, programmes:) }
  let(:session_b) { create(:session, team: team_b, programmes:) }
  let(:programmes) { [Programme.flu] }
  let(:patient) { create(:patient) }

  before do
    create(:patient_location, patient:, session: session_a)
    create(:patient_location, patient:, session: session_b)
  end

  context "when patient exists in multiple teams" do
    context "deceased" do
      before do
        patient.update_columns(
          # if we use update! the jobs gets called automatically
          date_of_death: Time.current,
          date_of_death_recorded_at: Time.current
        )
      end

      it "creates deceased notices for all associated teams" do
        expect { perform }.to change { team_a.important_notices.count }.by(
          1
        ).and change { team_b.important_notices.count }.by(1)

        expect(team_a.important_notices.first.type).to eq("deceased")
        expect(team_a.important_notices.first.message).to eq(
          "Record updated with child’s date of death"
        )

        expect { described_class.new.perform([patient.id]) }.to not_change(
          team_a.important_notices,
          :count
        ).and not_change(team_b.important_notices, :count)
      end
    end

    context "restricted" do
      before { patient.update_column(:restricted_at, Time.current) }

      it "creates restricted notices for all associated teams" do
        expect { perform }.to change(ImportantNotice, :count).by(2)

        notices = patient.important_notices.where(type: :restricted)
        expect(notices.pluck(:team_id)).to contain_exactly(team_a.id, team_b.id)
        expect(notices.first.can_dismiss?).to be true
        expect(notices.first.message).to eq("Record flagged as sensitive")
      end

      context "patient is no longer restricted" do
        before do
          patient.update!(restricted_at: Time.current)
          ImportantNoticeGeneratorSidekiqJob.drain
          patient.update_column(:restricted_at, nil)
        end

        it "dismisses existing restricted notices" do
          expect { perform }.to change {
            ImportantNotice
              .active(team: team_a)
              .where(patient:, type: :restricted)
              .count
          }.from(1).to(0)
        end
      end

      context "when a restricted notice was dismissed and the patient becomes restricted again" do
        before do
          # Create initial notices
          patient.update_column(:restricted_at, Time.current)
          described_class.perform_now([patient.id])

          # Clear restriction and dismiss notices
          patient.update_column(:restricted_at, nil)
          described_class.perform_now([patient.id])

          # Re-apply restriction
          patient.update_column(:restricted_at, Time.current)
        end

        it "creates a new active restricted notice (dismissed notices do not block re-creation)" do
          expect { described_class.perform_now([patient.id]) }.to change {
            ImportantNotice
              .active(team: team_a)
              .where(patient:, type: :restricted)
              .count
          }.from(0).to(1)

          expect(
            ImportantNotice
              .dismissed(team: team_a)
              .where(patient:, type: :restricted)
              .count
          ).to be >= 1
        end
      end
    end

    context "invalidated" do
      before { patient.update_column(:invalidated_at, Time.current) }

      it "creates invalidated notices for all associated teams" do
        expect { perform }.to change(ImportantNotice, :count).by(2)

        notices = patient.important_notices.where(type: :invalidated)
        expect(notices.pluck(:team_id)).to contain_exactly(team_a.id, team_b.id)
        expect(notices.first.can_dismiss?).to be false
        expect(notices.first.message).to eq("Record flagged as invalid")
      end

      context "patient is no longer invalidated" do
        before do
          patient.update!(invalidated_at: Time.current)
          ImportantNoticeGeneratorSidekiqJob.drain
          patient.update_column(:invalidated_at, nil)
        end

        it "dismisses existing invalidated notices" do
          expect { perform }.to change {
            ImportantNotice
              .active(team: team_a)
              .where(patient:, type: :invalidated)
              .count
          }.from(1).to(0)
        end
      end
    end

    context "gillick_no_notify" do
      it "creates notice only for vaccination team" do
        expect {
          create(
            :vaccination_record,
            patient: patient,
            team: team_a,
            notify_parents: false,
            programme: programmes.first,
            session: session_a
          )
        }.to enqueue_sidekiq_job(ImportantNoticeGeneratorSidekiqJob).with(
          [patient.id]
        )

        ImportantNoticeGeneratorSidekiqJob.drain

        expect(team_a.important_notices.count).to eq(1)
        expect(team_b.important_notices.count).to eq(0)

        expect(team_a.important_notices.first.type).to eq("gillick_no_notify")
        expect(team_a.important_notices.first.can_dismiss?).to be true
      end
    end

    context "team_changed" do
      let(:new_school) { create(:gias_school, team: team_b) }
      let(:team_changed_patient) { create(:patient, school: new_school) }
      let(:school_move_log_entry) do
        create(
          :school_move_log_entry,
          patient: team_changed_patient,
          school: new_school
        )
      end

      before do
        create(
          :patient_location,
          patient: team_changed_patient,
          session: session_b
        )
      end

      it "dismisses team_changed notice when patient's school is now in the team with the notice" do
        create(
          :important_notice,
          :team_changed,
          patient: team_changed_patient,
          team: team_b,
          school_move_log_entry:
        )

        expect {
          described_class.perform_now([team_changed_patient.id])
        }.to change {
          ImportantNotice
            .active(team: team_b)
            .team_changed
            .where(patient: team_changed_patient)
            .count
        }.from(1).to(0)
      end

      it "dismisses team_changed notice when patient has no school but has patient_location in the team" do
        patient_no_school = create(:patient, school: nil, team: team_a)
        create(
          :patient_location,
          patient: patient_no_school,
          session: session_a
        )

        school_move_log_entry_a =
          create(
            :school_move_log_entry,
            :unknown_school,
            patient: patient_no_school,
            team: team_b
          )

        create(
          :important_notice,
          :team_changed,
          patient: patient_no_school,
          team: team_a,
          school_move_log_entry: school_move_log_entry_a
        )

        expect {
          described_class.perform_now([patient_no_school.id])
        }.to change {
          ImportantNotice
            .active(team: team_a)
            .team_changed
            .where(patient: patient_no_school)
            .count
        }.from(1).to(0)
      end

      it "does not dismiss team_changed notice when patient has no school and no patient_location in the team" do
        patient_no_association = create(:patient, school: nil)

        school_move_log_entry_a =
          create(
            :school_move_log_entry,
            :home_educated,
            patient: patient_no_association,
            team: team_b
          )

        create(
          :important_notice,
          :team_changed,
          patient: patient_no_association,
          team: team_a,
          school_move_log_entry: school_move_log_entry_a
        )

        important_notices =
          ImportantNotice
            .active(team: team_a)
            .team_changed
            .where(patient: patient_no_association)

        expect {
          described_class.perform_now([patient_no_association.id])
        }.not_to change(important_notices, :count)
      end
    end
  end
end
