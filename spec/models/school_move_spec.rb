# frozen_string_literal: true

# == Schema Information
#
# Table name: school_moves
#
#  id            :bigint           not null, primary key
#  academic_year :integer          not null
#  source        :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  patient_id    :bigint           not null
#  school_id     :bigint           not null
#
# Indexes
#
#  index_school_moves_on_patient_id                (patient_id) UNIQUE
#  index_school_moves_on_patient_id_and_school_id  (patient_id,school_id)
#  index_school_moves_on_school_id                 (school_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (school_id => locations.id)
#
describe SchoolMove do
  describe "validations" do
    context "to a school" do
      subject(:school_move) { build(:school_move, :to_school) }

      it { should be_valid }
    end

    context "to home schooled" do
      subject(:school_move) { build(:school_move, :to_home_educated) }

      it { should be_valid }
    end

    context "to an unknown school" do
      subject(:school_move) { build(:school_move, :to_unknown_school) }

      it { should be_valid }
    end
  end

  describe "#confirm!" do
    subject(:confirm!) { school_move.confirm!(user:) }

    let(:today) { nil }
    let(:user) { create(:user) }
    let(:programmes) { [Programme.sample] }
    let(:team) { create(:team, programmes:) }

    let(:generic_clinic_session) do
      create(
        :session,
        academic_year:,
        team:,
        location: team.generic_clinic,
        programmes:
      )
    end

    around { |example| travel_to(today) { example.run } }

    shared_examples "creates a log entry" do
      it "creates a log entry" do
        expect { confirm! }.to change(
          patient.school_move_log_entries,
          :count
        ).by(1)

        expect(SchoolMoveLogEntry.last).to have_attributes(
          school: school_move.school,
          user:
        )
      end
    end

    shared_examples "sets the patient school" do
      it "sets the patient school" do
        expect { confirm! }.to change(patient, :school).to(school)
      end
    end

    shared_examples "sets the patient to home-schooled" do
      it "sets the patient to home-schooled" do
        expect { confirm! }.to change(patient, :school).to(school_move.school)
      end
    end

    shared_examples "adds the patient to the new school sessions" do
      it "adds the patient to the new school sessions" do
        expect(patient.sessions).not_to include(*new_sessions)
        confirm!
        expect(patient.reload.sessions).to include(*new_sessions)
      end
    end

    shared_examples "keeps the patient in the old school sessions" do
      it "keeps the patient in the old school sessions" do
        expect(patient.sessions).to include(session)
        confirm!
        expect(patient.reload.sessions).to include(session)
      end
    end

    shared_examples "removes the patient from the old school sessions" do
      it "removes the patient from the old school sessions" do
        expect(patient.sessions).to include(session)
        confirm!
        expect(patient.reload.sessions).not_to include(session)
      end
    end

    shared_examples "keeps the patient in the community clinic" do
      it "keeps the patient in the community clinic" do
        expect(patient.sessions).to include(generic_clinic_session)
        confirm!
        expect(patient.reload.sessions).to include(generic_clinic_session)
      end
    end

    shared_examples "removes the patient from the community clinic" do
      it "removes the patient from the community clinic" do
        expect(patient.sessions).to include(generic_clinic_session)
        confirm!
        expect(patient.reload.sessions).not_to include(generic_clinic_session)
      end
    end

    shared_examples "unarchives the patient" do
      it "unarchives the patient" do
        expect(patient.archived?(team:)).to be(true)
        confirm!
        expect(patient.archived?(team:)).to be(false)
      end
    end

    shared_examples "archives the patient in the original team" do
      it "archives the patient in the original team" do
        expect(patient.archived?(team:)).to be(false)
        expect(patient.archived?(team: new_team)).to be(false)
        confirm!
        expect(patient.archived?(team:)).to be(true)
        expect(patient.archived?(team: new_team)).to be(false)
      end
    end

    shared_examples "destroys the school move" do
      it "destroys the school move" do
        expect(school_move).to be_persisted
        expect { confirm! }.to change(described_class, :count).by(-1)
        expect { school_move.reload }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end
    end

    shared_examples "handles the school moves" do
      let(:academic_year) { AcademicYear.pending }

      context "with a patient in no sessions" do
        let(:patient) { create(:patient, team: nil, programmes:) }

        context "to a school with a scheduled session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to a school with a completed session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date - 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to home-schooled" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team:, patient:)
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "destroys the school move"
        end
      end

      context "with an archived patient" do
        let(:patient) { create(:patient, team: nil, programmes:) }

        before { create(:archive_reason, :imported_in_error, patient:, team:) }

        context "to a school with a scheduled session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "unarchives the patient"
          include_examples "destroys the school move"
        end

        context "to a school with a completed session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date - 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "unarchives the patient"
          include_examples "destroys the school move"
        end

        context "to home-schooled" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team:, patient:)
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "unarchives the patient"
          include_examples "destroys the school move"
        end
      end

      context "with a patient in a school session" do
        let(:session) do
          create(:session, date: session_date, team:, programmes:)
        end
        let(:patient) { create(:patient, session:) }

        context "to a school with a scheduled session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "removes the patient from the old school sessions"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to a school with a completed session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date - 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "removes the patient from the old school sessions"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to home-schooled" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team:, patient:)
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "removes the patient from the old school sessions"
          include_examples "destroys the school move"
        end

        context "to a school in a different team" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:new_team) { create(:team, programmes:) }
          let(:school) { create(:gias_school, team: new_team) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team: new_team,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "removes the patient from the old school sessions"
          include_examples "adds the patient to the new school sessions"
          include_examples "archives the patient in the original team"
          include_examples "destroys the school move"
        end

        context "to home-schooled in a different team" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team: new_team, patient:)
          end

          let(:new_team) { create(:team, programmes:) }
          let(:generic_clinic_session) do
            create(
              :session,
              academic_year:,
              team: new_team,
              location: new_team.generic_clinic,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "removes the patient from the old school sessions"
          include_examples "destroys the school move"
        end
      end

      context "with a home-schooled patient" do
        let(:patient) do
          create(:patient, :home_educated, session: generic_clinic_session)
        end

        context "to a school with a scheduled session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let!(:new_sessions) do # rubocop:disable RSpec/LetSetup
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to a school with a completed session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let!(:new_sessions) do # rubocop:disable RSpec/LetSetup
            create_list(
              :session,
              2,
              date: session_date - 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to home-schooled" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team:, patient:)
          end

          it "keeps the patient as home-schooled" do
            expect { confirm! }.not_to(change { patient.reload.school_id })
          end

          include_examples "creates a log entry"
          include_examples "keeps the patient in the community clinic"
          include_examples "destroys the school move"
        end

        context "to a school in a different team" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:new_team) { create(:team, programmes:) }
          let(:school) { create(:gias_school, team: new_team) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team: new_team,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "removes the patient from the community clinic"
          include_examples "archives the patient in the original team"
          include_examples "destroys the school move"
        end

        context "to home-schooled in a different team" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team: new_team, patient:)
          end

          let(:patient) do
            create(
              :patient,
              :home_educated,
              session:
                create(
                  :session,
                  academic_year:,
                  team:,
                  location: team.generic_clinic,
                  programmes:
                )
            )
          end
          let(:new_team) { create(:team, programmes:) }
          let(:generic_clinic_session) do
            create(
              :session,
              academic_year:,
              team: new_team,
              location: new_team.generic_clinic,
              programmes:
            )
          end

          it "keeps the patient as home-schooled" do
            expect { confirm! }.to change { patient.reload.school }.to(
              new_team.home_educated_school
            )
          end

          include_examples "creates a log entry"
          include_examples "destroys the school move"
        end
      end

      context "with a patient in an unknown school" do
        let(:patient) do
          create(:patient, school: nil, session: generic_clinic_session)
        end

        context "to a school with a scheduled session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let!(:new_sessions) do # rubocop:disable RSpec/LetSetup
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to a school with a completed session" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:school) { create(:gias_school, team:) }
          let!(:new_sessions) do # rubocop:disable RSpec/LetSetup
            create_list(
              :session,
              2,
              date: session_date - 1.week,
              location: school,
              team:,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "adds the patient to the new school sessions"
          include_examples "destroys the school move"
        end

        context "to home-schooled" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team:, patient:)
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "keeps the patient in the community clinic"
          include_examples "destroys the school move"
        end

        context "to a school in a different team" do
          let(:school_move) do
            create(:school_move, :to_school, patient:, school:)
          end

          let(:new_team) { create(:team, programmes:) }
          let(:school) { create(:gias_school, team: new_team) }
          let(:new_sessions) do
            create_list(
              :session,
              2,
              date: session_date + 1.week,
              location: school,
              team: new_team,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient school"
          include_examples "removes the patient from the community clinic"
          include_examples "archives the patient in the original team"
          include_examples "destroys the school move"
        end

        context "to home-schooled in a different team" do
          let(:school_move) do
            create(:school_move, :to_home_educated, team: new_team, patient:)
          end

          let(:patient) do
            create(
              :patient,
              school: nil,
              session:
                create(
                  :session,
                  academic_year:,
                  team:,
                  location: team.generic_clinic,
                  programmes:
                )
            )
          end
          let(:new_team) { create(:team, programmes:) }
          let(:generic_clinic_session) do
            create(
              :session,
              academic_year:,
              team: new_team,
              location: new_team.generic_clinic,
              programmes:
            )
          end

          include_examples "creates a log entry"
          include_examples "sets the patient to home-schooled"
          include_examples "destroys the school move"
        end
      end
    end

    context "the day before a preparation period" do
      let(:today) { Date.new(2025, 7, 31) }

      # Create sessions in the current academic year.
      let(:session_date) { Date.new(2025, 8, 15) }

      include_examples "handles the school moves"
    end

    context "the first day of a preparation period" do
      let(:today) { Date.new(2025, 8, 1) }

      # Create sessions in the next academic year.
      let(:session_date) { Date.new(2025, 9, 15) }

      include_examples "handles the school moves"
    end
  end

  describe "#ignore!" do
    subject(:ignore!) { school_move.ignore! }

    let(:patient) { create(:patient) }

    shared_examples "an ignored school move" do
      it "doesn't change the patient's school" do
        expect { ignore! }.not_to change(patient, :school)
      end

      it "destroys the school move" do
        expect(school_move).to be_persisted
        expect { ignore! }.to change(described_class, :count).by(-1)
        expect { school_move.reload }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end

      it "doesn't create a log entry" do
        expect { ignore! }.not_to change(SchoolMoveLogEntry, :count)
      end
    end

    context "to a school" do
      let(:school_move) { create(:school_move, :to_school, patient:) }

      it_behaves_like "an ignored school move"
    end

    context "to home schooled" do
      let(:school_move) { create(:school_move, :to_home_educated, patient:) }

      it_behaves_like "an ignored school move"
    end

    context "to an unknown school" do
      let(:school_move) { create(:school_move, :to_unknown_school, patient:) }

      it_behaves_like "an ignored school move"
    end
  end

  describe "#from_another_team?" do
    subject(:from_another_team?) { school_move.from_another_team? }

    let(:team_a) { create(:team) }
    let(:team_b) { create(:team) }
    let(:academic_year) { AcademicYear.pending }

    context "when patient has no current school" do
      let(:patient) { create(:patient, school: nil) }
      let(:new_school) { create(:gias_school, team: team_a) }
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      it { should be false }
    end

    context "when patient's current school has no teams" do
      let(:current_school) { create(:gias_school) }
      let(:patient) { create(:patient, school: current_school) }
      let(:new_school) { create(:gias_school, team: team_a) }
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      it { should be false }
    end

    context "when moving to home educated with same team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:patient) { create(:patient, school: current_school) }
      let(:school_move) do
        create(
          :school_move,
          :to_home_educated,
          patient:,
          team: team_a,
          academic_year:
        )
      end

      it { should be false }
    end

    context "when moving to home educated with different team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:patient) do
        create(:patient, school: current_school, location: current_school)
      end
      let(:school_move) do
        create(
          :school_move,
          :to_home_educated,
          patient:,
          team: team_b,
          academic_year:
        )
      end

      it { should be true }
    end

    context "when moving to unknown school with same team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:patient) { create(:patient, school: current_school) }
      let(:school_move) do
        create(
          :school_move,
          :to_unknown_school,
          patient:,
          team: team_a,
          academic_year:
        )
      end

      it { should be false }
    end

    context "when moving to unknown school with different team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:patient) do
        create(:patient, school: current_school, location: current_school)
      end
      let(:school_move) do
        create(
          :school_move,
          :to_unknown_school,
          patient:,
          team: team_b,
          academic_year:
        )
      end

      it { should be true }
    end

    context "when moving within the same team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:new_school) { create(:gias_school, team: team_a) }
      let(:patient) { create(:patient, school: current_school) }
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      it { should be false }
    end

    context "when current school is in multiple teams and moving to one of them" do
      let(:current_school) { create(:gias_school) }
      let(:new_school) { create(:gias_school, team: team_b) }
      let(:patient) { create(:patient, school: current_school) }
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      before do
        create(
          :team_location,
          team: team_a,
          location: current_school,
          academic_year:
        )
        create(
          :team_location,
          team: team_b,
          location: current_school,
          academic_year:
        )
      end

      it { should be false }
    end

    context "when moving to a different team" do
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:new_school) { create(:gias_school, team: team_b) }
      let(:patient) do
        create(:patient, school: current_school, location: current_school)
      end
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      it { should be true }
    end

    context "when moving to a school with multiple teams, none matching current" do
      let(:team_c) { create(:team) }
      let(:current_school) { create(:gias_school, team: team_a) }
      let(:new_school) { create(:gias_school) }
      let(:patient) do
        create(:patient, school: current_school, location: current_school)
      end
      let(:school_move) do
        create(:school_move, patient:, school: new_school, academic_year:)
      end

      before do
        create(
          :team_location,
          team: team_b,
          location: new_school,
          academic_year:
        )
        create(
          :team_location,
          team: team_c,
          location: new_school,
          academic_year:
        )
      end

      it { should be true }
    end
  end
end
