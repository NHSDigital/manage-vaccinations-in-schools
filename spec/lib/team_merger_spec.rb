# frozen_string_literal: true

describe TeamMerger do
  subject(:team_merger) { described_class.new(source_teams:, new_team_attrs:) }

  let(:organisation) { create(:organisation) }
  let(:source_teams) { [team_a, team_b] }
  let(:extra_attrs) { {} }
  let(:new_team_attrs) do
    {
      name: "Team Combined",
      workgroup: "team-combined",
      email: "combined@example.com",
      phone: "01234 567890",
      privacy_notice_url: "https://example.com/privacy-notice",
      privacy_policy_url: "https://example.com/privacy-policy",
      programme_types:
        (team_a.programme_types + team_b.programme_types).uniq.sort,
      type: team_a.type,
      organisation_id: organisation.id
    }.merge(extra_attrs)
  end
  let(:team_a) do
    create(
      :team,
      organisation:,
      workgroup: "team-a",
      name: "Team A",
      programmes: [Programme.hpv]
    )
  end
  let(:team_b) do
    create(
      :team,
      organisation:,
      workgroup: "team-b",
      name: "Team B",
      programmes: [Programme.flu]
    )
  end

  before do
    GenericLocationFactory.call(
      team: team_a,
      academic_year: AcademicYear.current
    )
    GenericLocationFactory.call(
      team: team_b,
      academic_year: AcademicYear.current
    )
  end

  describe "#valid?" do
    context "when teams share the same organisation and type" do
      it { should be_valid }
    end

    context "when teams belong to different organisations" do
      let(:other_org) { create(:organisation) }

      before { team_b.update_column(:organisation_id, other_org.id) }

      it "fails with a related error message" do
        expect(team_merger).not_to be_valid
        expect(team_merger.errors.first).to include("different organisations")
      end
    end

    context "when teams have different types" do
      before { team_b.update_column(:type, Team.types[:national_reporting]) }

      it "fails with a related error message" do
        expect(team_merger).not_to be_valid
        expect(team_merger.errors.first).to include("different types")
      end
    end

    context "with duplicate subteam names across source teams" do
      before do
        create(:subteam, team: team_a, name: "North")
        create(:subteam, team: team_b, name: "North")
      end

      it "fails with a related error message" do
        expect(team_merger).not_to be_valid
        expect(team_merger.errors.first).to include("Subteam 'North'")
      end
    end

    context "with team_locations for the same location but different subteams" do
      before do
        location = create(:school, :secondary)
        sub_a = create(:subteam, team: team_a, name: "Sub A")
        sub_b = create(:subteam, team: team_b, name: "Sub B")
        year = AcademicYear.current
        create(
          :team_location,
          team: team_a,
          location:,
          academic_year: year,
          subteam: sub_a
        )
        create(
          :team_location,
          team: team_b,
          location:,
          academic_year: year,
          subteam: sub_b
        )
      end

      it "fails with a related error message" do
        expect(team_merger).not_to be_valid
        expect(team_merger.errors.first).to include(
          "assigned to different subteams"
        )
      end
    end
  end

  describe "#dry_run" do
    subject(:dry_run_report) { team_merger.dry_run }

    context "without conflicts" do
      before do
        create(:consent, team: team_a)
        create(:cohort_import, team: team_b)
      end

      it "prints success messages" do
        expect(dry_run_report).to include(a_string_matching(/consents: 1 row/))
        expect(dry_run_report).to include(
          a_string_matching(/cohort_imports: 1 row/)
        )
        expect(dry_run_report).to include("Merge would succeed.")
      end

      it "doesn't create teams" do
        dry_run_report
        expect(Team.find_by(workgroup: "team-combined")).to be_nil
      end
    end

    context "with unresolvable conflicts" do
      before do
        create(:subteam, team: team_a, name: "Clash")
        create(:subteam, team: team_b, name: "Clash")
      end

      it "prints messages that merge would abort" do
        expect(dry_run_report).to include(
          a_string_matching(/ERROR:.*Subteam 'Clash'/)
        )
        expect(dry_run_report).to include(
          a_string_matching(/Merge would ABORT/)
        )
      end
    end

    context "with batch duplicates" do
      let(:vaccine) { Programme.flu.vaccines.first }

      before do
        create(
          :batch,
          team: team_a,
          vaccine:,
          number: "XY9999",
          expiry: Date.new(2026, 6, 1)
        )
        create(
          :batch,
          team: team_b,
          vaccine:,
          number: "XY9999",
          expiry: Date.new(2026, 6, 1)
        )
      end

      it "prints message that batch is duplicated" do
        expect(dry_run_report).to include(
          a_string_matching(/Batch XY9999.*duplicate/)
        )
      end
    end

    context "with patients to unarchive" do
      let(:patient) { create(:patient) }

      before do
        create(:archive_reason, :imported_in_error, team: team_a, patient:)
        create(
          :patient_team,
          team: team_b,
          patient:,
          sources: %i[patient_location]
        )
      end

      it "prints message that patient will be unarchived" do
        expect(dry_run_report).to include(
          a_string_matching(/will be unarchived/)
        )
      end
    end
  end

  describe "#call!" do
    context "with invalid merge" do
      before do
        create(:subteam, team: team_a, name: "Clash")
        create(:subteam, team: team_b, name: "Clash")
      end

      it "raises error" do
        expect { team_merger.call! }.to raise_error(TeamMerger::Error)
        expect(Team.find_by(workgroup: "team-combined")).to be_nil
      end
    end

    context "with valid merge" do
      subject(:merged_team) { team_merger.call! }

      context "simple associations" do
        let!(:consent_a) { create(:consent, team: team_a) }
        let!(:consent_b) { create(:consent, team: team_b) }

        it "migrates consents" do
          merged_team
          expect(consent_a.reload.team).to eq(merged_team)
          expect(consent_b.reload.team).to eq(merged_team)
        end

        it "destroys source teams" do
          merged_team
          expect(Team.where(id: [team_a.id, team_b.id])).to be_empty
        end
      end

      context "batch management" do
        let(:vaccine) { Programme.flu.vaccines.first }

        before do
          create(
            :batch,
            team: team_a,
            vaccine:,
            number: "SH001",
            expiry: Date.new(2026, 1, 1)
          )
          create(
            :batch,
            team: team_b,
            vaccine:,
            number: "SH001",
            expiry: Date.new(2026, 1, 1)
          )
          create(:batch, team: team_b, vaccine:, number: "UN002", expiry: nil)
        end

        it "merges unique batches" do
          expect(Batch.where(team: merged_team).pluck(:number)).to match_array(
            %w[SH001 UN002]
          )
        end
      end

      context "archive reasons" do
        let(:patient) { create(:patient) }

        context "single archive" do
          before do
            create(:archive_reason, :imported_in_error, team: team_a, patient:)
          end

          it { expect(ArchiveReason.where(team: merged_team).count).to eq(1) }
        end

        context "duplicate archives" do
          before do
            create(:archive_reason, :imported_in_error, team: team_a, patient:)
            create(:archive_reason, :imported_in_error, team: team_b, patient:)
          end

          it "combines archive reasons" do
            merged_team
            expect(ArchiveReason.where(team: merged_team).count).to eq(1)
          end
        end

        context "merged archive details" do
          before do
            create(:archive_reason, :imported_in_error, team: team_a, patient:)
            create(
              :archive_reason,
              :other,
              team: team_b,
              patient:,
              other_details: "reason from B"
            )
          end

          it "combines details" do
            ar = ArchiveReason.find_by!(team: merged_team, patient:)
            expect(ar.other_details).to include("Team A: Imported in error")
            expect(ar.other_details).to include("Team B: Other (reason from B)")
          end
        end

        context "active patient" do
          before do
            create(:archive_reason, :imported_in_error, team: team_a, patient:)
            create(
              :patient_location,
              patient:,
              session: create(:session, team: team_b)
            )
          end

          it "removes archive status" do
            merged_team
            expect(ArchiveReason.where(patient:)).to be_empty
          end

          it "maintains patient team associations" do
            pt = PatientTeam.find_by!(team: merged_team, patient:)
            expect(pt.sources).not_to include("archive_reason")
            expect(pt.sources).to include("patient_location")
          end
        end
      end

      context "patient teams" do
        let(:patient) { create(:patient) }

        context "merged sources" do
          before do
            create(
              :patient_location,
              patient:,
              session: create(:session, team: team_a)
            )
            create(
              :vaccination_record,
              patient:,
              immunisation_imports: [create(:immunisation_import, team: team_b)]
            )
            PatientTeamUpdater.call(
              patient_scope: Patient.where(id: patient.id)
            )
          end

          it "combines sources" do
            pt = PatientTeam.find_by(team: merged_team, patient:)
            expect(pt.sources).to include(
              "patient_location",
              "vaccination_record_import"
            )
          end
        end

        context "single team association" do
          before do
            create(
              :patient_location,
              patient:,
              session: create(:session, team: team_a)
            )
            PatientTeamUpdater.call(
              patient_scope: Patient.where(id: patient.id)
            )
          end

          it "preserves association" do
            expect(PatientTeam.where(team: merged_team, patient:)).to exist
          end
        end
      end

      context "subteams" do
        let!(:subteam) { create(:subteam, team: team_a, name: "North") }

        it "reassigns to merged team" do
          merged_team
          expect(subteam.reload.team).to eq(merged_team)
        end
      end

      context "team locations" do
        let(:location) { create(:school, :secondary) }

        context "single assignment" do
          let!(:tl) do
            create(
              :team_location,
              team: team_a,
              location:,
              academic_year: AcademicYear.current
            )
          end

          it "reassigns location" do
            merged_team
            expect(tl.reload.team).to eq(merged_team)
          end
        end

        context "duplicate locations" do
          let(:year) { AcademicYear.current }

          before do
            create(:team_location, team: team_a, location:, academic_year: year)
            create(:team_location, team: team_b, location:, academic_year: year)
          end

          it "deduplicates" do
            expect(
              TeamLocation.where(
                team: merged_team,
                location:,
                academic_year: year
              ).count
            ).to eq(1)
          end
        end
      end

      context "users" do
        let(:user) { create(:user, :nurse) }

        context "unique users" do
          before { team_a.users << user }

          it "migrates users" do
            expect(merged_team.users).to include(user)
          end
        end

        context "duplicate users" do
          before do
            team_a.users << user
            team_b.users << user
          end

          it "prevents duplicates" do
            expect(merged_team.users.where(id: user.id).count).to eq(1)
          end
        end
      end

      context "generic locations" do
        let(:year) { AcademicYear.current }

        before do
          GenericLocationFactory.call(team: team_a, academic_year: year)
          GenericLocationFactory.call(team: team_b, academic_year: year)
        end

        def generic_location(team)
          TeamLocation.find_by!(
            team:,
            academic_year: year,
            location: team.generic_clinics.first
          )
        end

        it "merges sessions" do
          tl_a = generic_location(team_a)
          session = create(:session, team_location: tl_a)
          merged_team
          expect(session.reload.team_location.location).to eq(
            merged_team.generic_clinics.first
          )
        end

        it "destroys old locations" do
          old_ids =
            Location
              .where(type: %i[generic_clinic generic_school])
              .joins(:team_locations)
              .where(team_locations: { team_id: [team_a.id, team_b.id] })
              .pluck(:id)
          merged_team
          expect(Location.where(id: old_ids)).to be_empty
        end

        it "handles patient locations" do
          tl_a = generic_location(team_a)
          tl_b = generic_location(team_b)
          patient = create(:patient)
          create(
            :patient_location,
            location: tl_a.location,
            patient:,
            academic_year: year
          )
          create(
            :patient_location,
            location: tl_b.location,
            patient:,
            academic_year: year
          )

          merged_team
          expect(
            PatientLocation.where(
              location: merged_team.generic_clinics.first,
              patient:,
              academic_year: year
            ).count
          ).to eq(1)
        end
      end

      context "programme types" do
        it "merges programmes" do
          expect(merged_team.programme_types).to match_array(%w[flu hpv])
        end
      end
    end
  end
end
