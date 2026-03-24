# frozen_string_literal: true

describe Stats::Organisations do
  describe "#call" do
    let(:programme_flu) { Programme.flu }
    let(:programme_hpv) { Programme.hpv }
    let(:programme_menacwy) { Programme.menacwy }

    let(:target_organisation) { create(:organisation, ods_code: "TARGET123") }
    let(:target_team) do
      create(:team, organisation: target_organisation, name: "Team Alpha")
    end
    let(:target_team2) do
      create(:team, organisation: target_organisation, name: "Team Beta")
    end

    let(:other_organisation) { create(:organisation, ods_code: "OTHER456") }
    let(:other_team) do
      create(:team, organisation: other_organisation, name: "Team Gamma")
    end

    let(:current_academic_year) { AcademicYear.current }
    let(:previous_academic_year) { current_academic_year - 1 }

    context "when organisation has complete data" do
      before { setup_complete_organisation_data }

      it "returns comprehensive statistics for all programmes" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu, programme_hpv],
            academic_year: current_academic_year
          )

        result = service.call

        expect(result[:ods_code]).to eq("TARGET123")
        expect(result[:team_names]).to include("Team Alpha", "Team Beta")
        expect(result[:programme_stats].size).to eq(2)

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        expect(flu_stats[:cohort_total][:total]).to eq(3)
        expect(flu_stats[:cohort_total][:years]).to include(
          8 => 1,
          9 => 1,
          11 => 1
        )
        expect(flu_stats[:school_total]).to eq(2)
      end

      it "filters by specific teams" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: [target_team],
            programmes: [programme_flu],
            academic_year: current_academic_year
          )

        result = service.call

        expect(result[:team_names]).to eq("Team Alpha")

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        expect(flu_stats[:cohort_total][:total]).to eq(2)
        expect(flu_stats[:cohort_total][:years]).to include(8 => 1, 9 => 1)
        expect(flu_stats[:cohort_total][:years]).not_to include(11)
      end

      it "filters by specific programmes" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_hpv],
            academic_year: current_academic_year
          )

        result = service.call

        expect(result[:programme_stats].size).to eq(1)
        expect(result[:programme_stats][0][:programme_name]).to eq("hpv")
      end

      it "filters by academic year" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu],
            academic_year: previous_academic_year
          )

        result = service.call

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        expect(flu_stats[:cohort_total][:total]).to eq(1)
      end

      it "calculates consent statistics correctly" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu],
            academic_year: current_academic_year
          )

        result = service.call

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        consent_stats = flu_stats[:consent_stats]

        expect(consent_stats[:total_consents]).to eq(3)
        expect(consent_stats[:patients_with_response_given]).to eq(1)
        expect(consent_stats[:patients_with_response_refused]).to eq(1)
        expect(consent_stats[:patients_with_no_response][:total]).to eq(1)
      end

      it "calculates vaccination statistics correctly" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu],
            academic_year: current_academic_year
          )

        result = service.call

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        vaccination_stats = flu_stats[:vaccination_stats]

        expect(vaccination_stats[:coverage_count]).to eq(1)
        expect(vaccination_stats[:vaccinated_in_mavis_count]).to eq(1)
        expect(vaccination_stats[:coverage_percentage]).to eq(33.33)
      end

      it "calculates communications statistics correctly" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu],
            academic_year: current_academic_year
          )

        result = service.call

        flu_stats =
          result[:programme_stats].find { it[:programme_name] == "flu" }
        comms_stats = flu_stats[:comms_stats]

        expect(comms_stats[:schools_involved]).to eq(1)
        expect(comms_stats[:patients_with_comms]).to eq(2)
        expect(comms_stats[:patients_with_requests]).to eq(2)
        expect(comms_stats[:patients_with_reminders]).to eq(1)
      end
    end

    context "when organisation has no data" do
      it "returns zero counts for all statistics" do
        service =
          described_class.new(
            organisation: target_organisation,
            teams: target_organisation.teams,
            programmes: [programme_flu],
            academic_year: current_academic_year
          )

        result = service.call

        expect(result[:programme_stats].size).to eq(1)
        flu_stats = result[:programme_stats][0]
        expect(flu_stats[:cohort_total][:total]).to eq(0)
        expect(flu_stats[:school_total]).to eq(0)
        expect(flu_stats[:consent_stats][:total_consents]).to eq(0)
        expect(flu_stats[:vaccination_stats][:coverage_count]).to eq(0)
      end
    end

    private

    def setup_complete_organisation_data
      target_team.programmes << [programme_flu, programme_hpv]
      target_team2.programmes << [programme_flu]

      school1 =
        create(
          :gias_school,
          name: "Primary School",
          team: target_team,
          programmes: [programme_flu, programme_hpv]
        )
      school1.import_year_groups_from_gias!(
        academic_year: previous_academic_year
      )
      school1.import_default_programme_year_groups!(
        [programme_flu, programme_hpv],
        academic_year: previous_academic_year
      )

      school2 =
        create(
          :gias_school,
          name: "Secondary School",
          team: target_team2,
          programmes: [programme_flu]
        )

      session1 =
        create(
          :session,
          team: target_team,
          location: school1,
          programmes: [programme_flu],
          academic_year: current_academic_year
        )
      session2 =
        create(
          :session,
          team: target_team2,
          location: school2,
          programmes: [programme_flu],
          academic_year: current_academic_year
        )
      old_session =
        create(
          :session,
          date: Date.new(previous_academic_year, 12, 1),
          team: target_team,
          location: school1,
          programmes: [programme_flu],
          academic_year: previous_academic_year
        )

      patient_8 =
        create(
          :patient,
          :consent_given_triage_not_needed,
          :vaccinated,
          year_group: 8,
          session: session1
        )
      patient_9 =
        create(:patient, :consent_refused, year_group: 9, session: session1)
      create(:patient, :consent_no_response, year_group: 11, session: session2)
      create(:patient, :consent_refused, year_group: 8, session: old_session)

      create(
        :consent_notification,
        :request,
        patient: patient_8,
        session: session1
      )
      create(
        :consent_notification,
        :request,
        patient: patient_9,
        session: session1
      )
      create(
        :consent_notification,
        :initial_reminder,
        patient: patient_8,
        session: session1
      )
    end
  end
end
