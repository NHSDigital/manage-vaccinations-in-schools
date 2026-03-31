# frozen_string_literal: true

describe TeamMerger do
  let(:organisation) { create(:organisation) }
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

  def build_service(source_teams: [team_a, team_b], extra_attrs: {})
    new_team_attrs = {
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

    TeamMerger.new(source_teams:, new_team_attrs:)
  end

  describe "#valid?" do
    context "when teams share the same organisation and type" do
      it "returns true" do
        expect(build_service.valid?).to be true
      end
    end

    context "when teams belong to different organisations" do
      it "returns false with an error" do
        other_org = create(:organisation)
        team_b.update_column(:organisation_id, other_org.id)
        service = build_service
        expect(service.valid?).to be false
        expect(service.errors.first).to include("different organisations")
      end
    end

    context "when teams have different types" do
      it "returns false with an error" do
        team_b.update_column(:type, Team.types[:national_reporting])
        service = build_service
        expect(service.valid?).to be false
        expect(service.errors.first).to include("different types")
      end
    end

    context "with duplicate subteam names across source teams" do
      it "returns false with an error" do
        create(:subteam, team: team_a, name: "North")
        create(:subteam, team: team_b, name: "North")

        service = build_service
        expect(service.valid?).to be false
        expect(service.errors.first).to include("Subteam 'North'")
      end
    end

    context "with team_locations for the same location but different subteams" do
      it "returns false with an error" do
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

        service = build_service
        expect(service.valid?).to be false
        expect(service.errors.first).to include(
          "assigned to different subteams"
        )
      end
    end
  end

  describe "#dry_run" do
    it "returns a report without making changes" do
      create(:consent, team: team_a)
      create(:cohort_import, team: team_b)

      service = build_service
      report = service.dry_run

      expect(report).to include(a_string_matching(/consents: 1 row/))
      expect(report).to include(a_string_matching(/cohort_imports: 1 row/))
      expect(report).to include("Merge would succeed.")

      expect(Team.find_by(workgroup: "team-combined")).to be_nil
    end

    it "reports unresolvable conflicts" do
      create(:subteam, team: team_a, name: "Clash")
      create(:subteam, team: team_b, name: "Clash")

      service = build_service
      report = service.dry_run

      expect(report).to include(a_string_matching(/ERROR:.*Subteam 'Clash'/))
      expect(report).to include(a_string_matching(/Merge would ABORT/))
    end

    it "reports batch duplicates" do
      vaccine = Programme.flu.vaccines.first
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

      service = build_service
      report = service.dry_run

      expect(report).to include(a_string_matching(/Batch XY9999.*duplicate/))
    end

    it "reports patients that will be unarchived" do
      patient = create(:patient)
      create(:archive_reason, :imported_in_error, team: team_a, patient:)
      create(
        :patient_team,
        team: team_b,
        patient:,
        sources: %i[patient_location]
      )

      service = build_service
      report = service.dry_run

      expect(report).to include(a_string_matching(/will be unarchived/))
    end
  end

  describe "#call!" do
    context "simple table migration" do
      it "reassigns consents to the merged team and destroys source teams" do
        consent_a = create(:consent, team: team_a)
        consent_b = create(:consent, team: team_b)

        merged_team = build_service.call!

        expect(consent_a.reload.team).to eq(merged_team)
        expect(consent_b.reload.team).to eq(merged_team)
        expect(Team.where(id: [team_a.id, team_b.id])).to be_empty
      end
    end

    context "batch deduplication" do
      it "skips duplicate batches and migrates unique ones" do
        vaccine = Programme.flu.vaccines.first
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

        merged_team = build_service.call!

        expect(Batch.where(team: merged_team).pluck(:number)).to match_array(
          %w[SH001 UN002]
        )
      end
    end

    context "archive reason migration" do
      it "migrates unique archive reasons" do
        patient = create(:patient)
        create(:archive_reason, :imported_in_error, team: team_a, patient:)

        merged_team = build_service.call!

        expect(ArchiveReason.where(team: merged_team).count).to eq(1)
      end

      it "keeps one record when patient is fully archived with the same type in both teams" do
        patient = create(:patient)
        create(:archive_reason, :imported_in_error, team: team_a, patient:)
        create(:archive_reason, :imported_in_error, team: team_b, patient:)

        merged_team = build_service.call!

        expect(ArchiveReason.where(team: merged_team).count).to eq(1)
      end

      it "merges details when patient is fully archived both teams with different reasons" do
        patient = create(:patient)
        create(:archive_reason, :imported_in_error, team: team_a, patient:)
        create(
          :archive_reason,
          :other,
          team: team_b,
          patient:,
          other_details: "reason from B"
        )

        merged_team = build_service.call!

        ar = ArchiveReason.find_by!(team: merged_team, patient:)
        expect(ar.other_details).to include("Team A: Imported in error")
        expect(ar.other_details).to include("Team B: Other (reason from B)")
      end

      it "deletes archive reason when patient is active in at least one source team" do
        patient = create(:patient)
        create(:archive_reason, :imported_in_error, team: team_a, patient:)
        create(
          :patient_location,
          patient:,
          session: create(:session, team: team_b)
        )

        merged_team = build_service.call!

        expect(ArchiveReason.where(patient:)).to be_empty
        pt = PatientTeam.find_by!(team: merged_team, patient:)
        expect(pt.sources).not_to include("archive_reason")
        expect(pt.sources).to include("patient_location")
      end
    end

    context "patient_teams migration" do
      it "merges sources when the same patient appears in both source teams" do
        patient = create(:patient)
        create(
          :patient_location,
          patient:,
          session: create(:session, team: team_a)
        )
        create(
          :vaccination_record,
          patient:,
          team: nil,
          immunisation_imports: [create(:immunisation_import, team: team_b)]
        )
        PatientTeamUpdater.call(patient_scope: Patient.where(id: patient.id))

        merged_team = build_service.call!

        pt = PatientTeam.find_by(team: merged_team, patient:)
        expect(pt.sources).to include(
          "patient_location",
          "vaccination_record_import"
        )
      end

      it "migrates patient_teams that exist in only one source team" do
        patient = create(:patient)
        create(
          :patient_location,
          patient:,
          session: create(:session, team: team_a)
        )
        PatientTeamUpdater.call(patient_scope: Patient.where(id: patient.id))

        merged_team = build_service.call!

        expect(PatientTeam.where(team: merged_team, patient:)).to exist
      end
    end

    context "subteam migration" do
      it "reassigns subteams to the merged team" do
        sub = create(:subteam, team: team_a, name: "North")

        merged_team = build_service.call!

        expect(sub.reload.team).to eq(merged_team)
      end
    end

    context "team_location migration" do
      it "migrates team_locations to the merged team" do
        location = create(:school, :secondary)
        tl =
          create(
            :team_location,
            team: team_a,
            location:,
            academic_year: AcademicYear.current
          )

        merged_team = build_service.call!

        expect(tl.reload.team).to eq(merged_team)
      end

      it "skips duplicate team_locations" do
        location = create(:school, :secondary)
        year = AcademicYear.current
        create(:team_location, team: team_a, location:, academic_year: year)
        create(:team_location, team: team_b, location:, academic_year: year)

        merged_team = build_service.call!

        expect(
          TeamLocation.where(
            team: merged_team,
            location:,
            academic_year: year
          ).count
        ).to eq(1)
      end
    end

    context "users (teams_users) migration" do
      it "reassigns unique users to the merged team" do
        user = create(:user, :nurse)
        team_a.users << user

        merged_team = build_service.call!

        expect(merged_team.users).to include(user)
      end

      it "does not duplicate users already in both teams" do
        user = create(:user, :nurse)
        team_a.users << user
        team_b.users << user

        merged_team = build_service.call!

        expect(merged_team.users.where(id: user.id).count).to eq(1)
      end
    end

    context "when merge is invalid" do
      it "raises TeamMerger::Error" do
        create(:subteam, team: team_a, name: "Clash")
        create(:subteam, team: team_b, name: "Clash")

        service = build_service
        expect { service.call! }.to raise_error(TeamMerger::Error)
        expect(Team.find_by(workgroup: "team-combined")).to be_nil
      end
    end

    context "generic location migration" do
      let(:year) { AcademicYear.current }

      def gc_tl(team)
        GenericLocationFactory.call(team:, academic_year: year)
        TeamLocation.find_by!(
          team:,
          academic_year: year,
          location: team.generic_clinics.first
        )
      end

      it "merges sessions and consent_forms into the merged generic clinic" do
        tl_a = gc_tl(team_a)
        tl_b = gc_tl(team_b)
        session = create(:session, team_location: tl_a)
        consent_form = create(:consent_form, team_location: tl_b)

        merged_team = build_service.call!

        merged_tl =
          TeamLocation.find_by!(
            team: merged_team,
            location: merged_team.generic_clinics.first,
            academic_year: year
          )
        expect(session.reload.team_location).to eq(merged_tl)
        expect(consent_form.reload.team_location).to eq(merged_tl)
      end

      it "destroys old generic clinic locations" do
        tl_a = gc_tl(team_a)
        tl_b = gc_tl(team_b)
        old_location_ids = [tl_a.location_id, tl_b.location_id]

        build_service.call!

        expect(Location.where(id: old_location_ids)).to be_empty
      end

      it "migrates patient_locations and deduplicates across source teams" do
        tl_a = gc_tl(team_a)
        tl_b = gc_tl(team_b)
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

        merged_team = build_service.call!

        expect(
          PatientLocation.where(
            location: merged_team.generic_clinics.first,
            patient:,
            academic_year: year
          ).count
        ).to eq(1)
      end

      it "re-points vaccination records to the merged generic clinic" do
        tl_a = gc_tl(team_a)
        record = create(:vaccination_record, location: tl_a.location)

        merged_team = build_service.call!

        expect(record.reload.location).to eq(merged_team.generic_clinics.first)
      end

      it "migrates sessions from generic_school team_locations" do
        GenericLocationFactory.call(team: team_a, academic_year: year)
        GenericLocationFactory.call(team: team_b, academic_year: year)

        hs_tl_a =
          TeamLocation.find_by!(
            team: team_a,
            academic_year: year,
            location:
              team_a.generic_schools.find_by!(urn: Location::URN_HOME_EDUCATED)
          )
        session = create(:session, team_location: hs_tl_a)

        merged_team = build_service.call!

        merged_hs =
          merged_team.generic_schools.find_by!(urn: Location::URN_HOME_EDUCATED)
        merged_tl =
          TeamLocation.find_by!(
            team: merged_team,
            location: merged_hs,
            academic_year: year
          )
        expect(session.reload.team_location).to eq(merged_tl)
      end

      it "destroys all old generic location records (clinic and schools)" do
        GenericLocationFactory.call(team: team_a, academic_year: year)
        GenericLocationFactory.call(team: team_b, academic_year: year)

        old_ids =
          Location
            .where(type: %i[generic_clinic generic_school])
            .joins(:team_locations)
            .where(team_locations: { team_id: [team_a.id, team_b.id] })
            .pluck(:id)

        build_service.call!

        expect(Location.where(id: old_ids)).to be_empty
      end
    end

    context "programme_types" do
      it "defaults to the union of source team programme_types" do
        merged_team = build_service.call!
        expect(merged_team.programme_types).to match_array(%w[flu hpv])
      end
    end
  end
end
