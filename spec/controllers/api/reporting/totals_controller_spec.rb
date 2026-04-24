# frozen_string_literal: true

describe API::Reporting::TotalsController do
  before { request.headers["Authorization"] = "Bearer #{valid_jwt}" }

  include ReportingAPIHelper

  let(:parsed_response) { JSON.parse(response.body) }

  it_behaves_like "a ReportingAPI controller"

  describe "#index" do
    it "returns all expected keys" do
      get :index

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to have_key("cohort")
      expect(parsed_response).to have_key("vaccinated")
      expect(parsed_response).to have_key("not_vaccinated")
      expect(parsed_response).to have_key("vaccinations_given")
      expect(parsed_response).to have_key("monthly_vaccinations_given")
      expect(parsed_response).to have_key("consent_refusal_reasons")
      expect(parsed_response).to have_key("consent_routes")
    end

    it "calculates statistics correctly" do
      team = Team.last # The most recently created team from valid_jwt
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      # Patient 1: Vaccinated
      patient1 = create(:patient, session:)
      create(
        :vaccination_record,
        patient: patient1,
        programme:,
        session:,
        outcome: "administered"
      )

      # Patient 2: Vaccinated
      patient2 = create(:patient, session:)
      create(
        :vaccination_record,
        patient: patient2,
        programme:,
        session:,
        outcome: "administered"
      )

      # Patient 3: Not vaccinated (should be counted as not_vaccinated)
      create(:patient, session:)

      refresh_reporting_views!

      get :index

      expect(response).to have_http_status(:ok)

      cohort = parsed_response["cohort"]
      vaccinated = parsed_response["vaccinated"]
      not_vaccinated = parsed_response["not_vaccinated"]

      expect(cohort).to eq(3) # 3 distinct patients
      expect(vaccinated).to eq(2) # patient1 and patient2
      expect(not_vaccinated).to eq(1) # patient3
      expect(vaccinated + not_vaccinated).to eq(cohort)

      expect(parsed_response["vaccinations_given"]).to eq(
        { "school_count" => 2, "community_count" => 0 }
      )
      expect(parsed_response["monthly_vaccinations_given"]).to be_an(Array)
    end

    it "filters by multiple year groups" do
      team = Team.last
      programme = Programme.flu
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      create(:patient, session:, year_group: 8)
      create(:patient, session:, year_group: 8)
      create(:patient, session:, year_group: 9)
      create(:patient, session:, year_group: 10)
      create(:patient, session:, year_group: 10)

      refresh_reporting_views!

      get :index, params: { year_group: [8, 9] }

      expect(response).to have_http_status(:ok)
      expect(parsed_response["cohort"]).to eq(3)
    end

    it "filters by workgroup" do
      programme = Programme.flu

      team = Team.last
      team.programmes << programme

      other_team = create(:team, organisation: team.organisation)
      other_team.programmes << programme

      session = create(:session, team:, programmes: [programme])
      other_session =
        create(:session, team: other_team, programmes: [programme])

      create(:patient, session:)
      create(:patient, session:)
      create(:patient, session: other_session)

      refresh_reporting_views!

      get :index, params: { workgroup: team.workgroup }

      expect(response).to have_http_status(:ok)
      expect(parsed_response["cohort"]).to eq(2)
    end

    it "filters by team_workgroup from session when no workgroup param" do
      programme = Programme.flu
      team = Team.last
      team.programmes << programme
      other_team = create(:team, organisation: team.organisation)
      other_team.programmes << programme

      user = team.users.first
      user.teams << other_team

      create(
        :patient,
        session: create(:session, team:, programmes: [programme])
      )
      create(
        :patient,
        session: create(:session, team:, programmes: [programme])
      )
      create(
        :patient,
        session: create(:session, team: other_team, programmes: [programme])
      )

      refresh_reporting_views!

      jwt =
        JWT.encode(
          {
            data: {
              user: user.as_json,
              cis2_info: {
                organisation_code: team.organisation.ods_code,
                workgroups: [team.workgroup, other_team.workgroup],
                team_workgroup: team.workgroup,
                role_code: CIS2Info::NURSE_ROLES.first
              }
            }
          },
          Settings.reporting_api.client_app.secret,
          "HS512"
        )
      request.headers["Authorization"] = "Bearer #{jwt}"

      get :index

      expect(response).to have_http_status(:ok)
      expect(parsed_response["cohort"]).to eq(2)
    end

    it "returns grouped JSON data by school" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      school_one = create(:gias_school, name: "School One", urn: "111111")
      school_two = create(:gias_school, name: "School Two", urn: "222222")

      create(:patient, session:, school: school_one)
      patient2 = create(:patient, session:, school: school_two)
      create(
        :vaccination_record,
        patient: patient2,
        programme:,
        session:,
        outcome: "administered",
        performed_at: Time.current
      )

      create(:patient, session:, school: team.home_educated_school)
      create(:patient, session:, school: team.unknown_school)

      refresh_reporting_views!

      get :index, params: { group: "school", programme: "hpv" }

      expect(response).to have_http_status(:ok)
      expect(parsed_response).to be_an(Array)
      expect(parsed_response.length).to eq(4)

      school_one_data = parsed_response.find { it["school_urn"] == "111111" }
      school_two_data = parsed_response.find { it["school_urn"] == "222222" }
      home_educated_data = parsed_response.find { it["school_urn"] == "999999" }
      unknown_data = parsed_response.find { it["school_urn"] == "888888" }

      expect(school_one_data["school_name"]).to eq("School One")
      expect(school_one_data["cohort"]).to eq(1)
      expect(school_one_data["vaccinated"]).to eq(0)
      expect(school_one_data["not_vaccinated"]).to eq(1)

      expect(school_two_data["school_name"]).to eq("School Two")
      expect(school_two_data["cohort"]).to eq(1)
      expect(school_two_data["vaccinated"]).to eq(1)
      expect(school_two_data["not_vaccinated"]).to eq(0)

      expect(home_educated_data["school_name"]).to eq("Home-educated")
      expect(home_educated_data["cohort"]).to eq(1)
      expect(home_educated_data["vaccinated"]).to eq(0)
      expect(home_educated_data["not_vaccinated"]).to eq(1)

      expect(unknown_data["school_name"]).to eq("Unknown school")
      expect(unknown_data["cohort"]).to eq(1)
      expect(unknown_data["vaccinated"]).to eq(0)
      expect(unknown_data["not_vaccinated"]).to eq(1)
    end

    it "includes consent columns in grouped JSON response" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      school = create(:gias_school, name: "Test School", urn: "123456")

      patient1 =
        create(
          :patient,
          session:,
          school:,
          year_group: 8,
          parents: [create(:parent)]
        )
      create(:consent, :given, patient: patient1, programme:, team:)
      PatientStatusUpdater.call(patient: patient1)

      patient2 =
        create(
          :patient,
          session:,
          school:,
          year_group: 8,
          parents: [create(:parent)]
        )
      create(:consent, :refused, patient: patient2, programme:, team:)
      PatientStatusUpdater.call(patient: patient2)

      patient3 =
        create(
          :patient,
          session:,
          school:,
          year_group: 8,
          parents: [create(:parent)]
        )

      [patient1, patient2, patient3].each do |patient|
        create(
          :consent_notification,
          :request,
          patient:,
          session:,
          programmes: [programme]
        )
      end

      refresh_reporting_views!

      get :index, params: { group: "school", programme: "hpv" }

      expect(response).to have_http_status(:ok)

      school_data = parsed_response.find { it["school_urn"] == "123456" }
      expect(school_data).to include(
        "consent_given" => 1,
        "no_consent" => 2,
        "consent_no_response" => 1,
        "consent_refused" => 1,
        "consent_conflicts" => 0
      )
    end

    it "counts all no response consent statuses consistently in aggregate totals" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme

      session = create(:session, team:, programmes: [programme])

      no_response_patient =
        create(:patient, session:, parents: [create(:parent)])
      create(
        :consent_notification,
        :request,
        patient: no_response_patient,
        session:,
        programmes: [programme]
      )

      create(:patient, session:, parents: [create(:parent, :non_contactable)])

      request_scheduled_session =
        create(
          :session,
          team:,
          programmes: [programme],
          send_consent_requests_at: Date.tomorrow
        )
      create(
        :patient,
        session: request_scheduled_session,
        parents: [create(:parent)]
      )

      create(:patient, session:, parents: [create(:parent)])

      refused_patient = create(:patient, session:, parents: [create(:parent)])
      create(:consent, :refused, patient: refused_patient, programme:, team:)

      conflict_patient = create(:patient, session:)
      parent1 = create(:parent)
      parent2 = create(:parent)
      create(:parent_relationship, patient: conflict_patient, parent: parent1)
      create(:parent_relationship, patient: conflict_patient, parent: parent2)
      create(
        :consent,
        :given,
        patient: conflict_patient,
        programme:,
        team:,
        parent: parent1
      )
      create(
        :consent,
        :refused,
        patient: conflict_patient,
        programme:,
        team:,
        parent: parent2
      )

      PatientStatusUpdater.call

      refresh_reporting_views!

      get :index, params: { programme: "hpv" }

      expect(parsed_response["no_consent"]).to eq(6)
      expect(parsed_response["consent_refused"]).to eq(1)
      expect(parsed_response["consent_conflicts"]).to eq(1)
      expect(parsed_response["consent_no_response"]).to eq(4)
    end

    describe "consent breakdowns" do
      let(:team) { Team.last }
      let(:programme) { Programme.hpv }
      let(:session) { create(:session, team:, programmes: [programme]) }

      before { team.programmes << programme }

      it "returns the breakdown shape with zero counts when no consents exist" do
        create(:patient, session:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        expect(parsed_response["consent_refusal_reasons"]).to eq(
          "contains_gelatine" => 0,
          "already_vaccinated" => 0,
          "will_be_vaccinated_elsewhere" => 0,
          "medical_reasons" => 0,
          "personal_choice" => 0,
          "other" => 0,
          "do_not_want_vaccination_at_school" => 0
        )
        expect(parsed_response["consent_routes"]).to eq(
          "website" => 0,
          "phone" => 0,
          "paper" => 0,
          "in_person" => 0,
          "self_consent" => 0
        )
      end

      it "counts each parent's refusal reason when two parents refuse the same patient" do
        patient = create(:patient, session:)
        parent_one = create(:parent)
        parent_two = create(:parent)
        create(:parent_relationship, patient:, parent: parent_one)
        create(:parent_relationship, patient:, parent: parent_two)
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          team:,
          parent: parent_one,
          reason_for_refusal: "medical_reasons"
        )
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          team:,
          parent: parent_two,
          reason_for_refusal: "personal_choice"
        )
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        reasons = parsed_response["consent_refusal_reasons"]
        expect(reasons["medical_reasons"]).to eq(1)
        expect(reasons["personal_choice"]).to eq(1)
      end

      it "counts each parent's route when two parents respond via different routes" do
        patient = create(:patient, session:)
        parent_one = create(:parent)
        parent_two = create(:parent)
        recorded_by = create(:user)
        create(:parent_relationship, patient:, parent: parent_one)
        create(:parent_relationship, patient:, parent: parent_two)
        create(
          :consent,
          :given,
          patient:,
          programme:,
          team:,
          parent: parent_one,
          route: "website"
        )
        create(
          :consent,
          :given,
          patient:,
          programme:,
          team:,
          parent: parent_two,
          route: "phone",
          recorded_by:
        )
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        routes = parsed_response["consent_routes"]
        expect(routes["website"]).to eq(1)
        expect(routes["phone"]).to eq(1)
      end

      it "counts only the latest consent when one parent updates their refusal reason" do
        patient = create(:patient, session:)
        parent = create(:parent)
        create(:parent_relationship, patient:, parent:)
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          team:,
          parent:,
          reason_for_refusal: "medical_reasons",
          submitted_at: 2.days.ago
        )
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          team:,
          parent:,
          reason_for_refusal: "personal_choice",
          submitted_at: 1.day.ago
        )
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        reasons = parsed_response["consent_refusal_reasons"]
        expect(reasons["medical_reasons"]).to eq(0)
        expect(reasons["personal_choice"]).to eq(1)
      end

      it "counts the refusal reason for a patient in conflicts status" do
        patient = create(:patient, session:)
        parent_giving = create(:parent)
        parent_refusing = create(:parent)
        create(:parent_relationship, patient:, parent: parent_giving)
        create(:parent_relationship, patient:, parent: parent_refusing)
        create(
          :consent,
          :given,
          patient:,
          programme:,
          team:,
          parent: parent_giving,
          route: "website"
        )
        create(
          :consent,
          :refused,
          patient:,
          programme:,
          team:,
          parent: parent_refusing,
          reason_for_refusal: "medical_reasons",
          route: "phone",
          recorded_by: create(:user)
        )
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        expect(parsed_response["consent_conflicts"]).to eq(1)
        expect(
          parsed_response["consent_refusal_reasons"]["medical_reasons"]
        ).to eq(1)
        expect(parsed_response["consent_routes"]["website"]).to eq(1)
        expect(parsed_response["consent_routes"]["phone"]).to eq(1)
      end

      it "counts both self-consent and parental consent on the same patient" do
        patient = create(:patient, session:, year_group: 11)
        parent = create(:parent)
        create(:parent_relationship, patient:, parent:)
        create(
          :consent,
          :given,
          patient:,
          programme:,
          team:,
          parent:,
          route: "website"
        )
        create(:consent, :given, :self_consent, patient:, programme:, team:)
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        routes = parsed_response["consent_routes"]
        expect(routes["website"]).to eq(1)
        expect(routes["self_consent"]).to eq(1)
      end

      it "excludes invalidated and withdrawn consents" do
        patient = create(:patient, session:)
        parent_one = create(:parent)
        parent_two = create(:parent)
        create(:parent_relationship, patient:, parent: parent_one)
        create(:parent_relationship, patient:, parent: parent_two)
        create(
          :consent,
          :refused,
          :invalidated,
          patient:,
          programme:,
          team:,
          parent: parent_one,
          reason_for_refusal: "medical_reasons"
        )
        create(
          :consent,
          :refused,
          :withdrawn,
          patient:,
          programme:,
          team:,
          parent: parent_two,
          reason_for_refusal: "personal_choice"
        )
        PatientStatusUpdater.call(patient:)

        refresh_reporting_views!

        get :index, params: { programme: "hpv" }

        reasons = parsed_response["consent_refusal_reasons"]
        expect(reasons["medical_reasons"]).to eq(0)
        expect(reasons["personal_choice"]).to eq(0)
      end
    end
  end

  describe "#index.csv" do
    it "returns grouped CSV data by year group" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      create(:patient, session:, year_group: 8)
      create(:patient, session:, year_group: 9)

      refresh_reporting_views!

      request.headers["Accept"] = "text/csv"
      get :index, params: { group: "year_group" }, format: :csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("text/csv")

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include("Year Group", "Cohort", "Vaccinated")
      expect(csv.length).to eq(2)
    end

    it "returns grouped CSV data by school" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      school_one = create(:gias_school, name: "School One", urn: "111111")
      school_two = create(:gias_school, name: "School Two", urn: "222222")

      create(:patient, session:, school: school_one)
      create(:patient, session:, school: school_two)

      refresh_reporting_views!

      request.headers["Accept"] = "text/csv"
      get :index, params: { group: "school" }, format: :csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("text/csv")

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include(
        "School URN",
        "School Name",
        "Cohort",
        "Vaccinated"
      )
      expect(csv.length).to eq(2)
    end

    it "returns grouped CSV data by local authority with official names" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      school_one =
        create(:gias_school, name: "School One", gias_local_authority_code: 201)
      school_two =
        create(:gias_school, name: "School Two", gias_local_authority_code: 202)

      create(:patient, session:, school: school_one)
      create(:patient, session:, school: school_two)

      refresh_reporting_views!

      request.headers["Accept"] = "text/csv"
      get :index, params: { group: "local_authority" }, format: :csv

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("text/csv")

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include("Local Authority", "Cohort", "Vaccinated")
      expect(csv.length).to eq(2)

      local_authorities = csv.map { it["Local Authority"] }
      expect(local_authorities).to contain_exactly(
        "Test Authority 201",
        "Test Authority 202"
      )
    end

    it "returns Unknown Local Authority for patients without school or postcode LA" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      # Patient with school that has LA
      school =
        create(
          :gias_school,
          name: "Known School",
          gias_local_authority_code: 201
        )
      create(:patient, session:, school:)

      # Home-educated patient without postcode LA lookup
      create(
        :patient,
        session:,
        school: team.home_educated_school,
        local_authority_mhclg_code: nil
      )

      # Unknown school patient without postcode LA lookup
      create(
        :patient,
        session:,
        school: team.unknown_school,
        local_authority_mhclg_code: nil
      )

      refresh_reporting_views!

      request.headers["Accept"] = "text/csv"
      get :index, params: { group: "local_authority" }, format: :csv

      expect(response).to have_http_status(:ok)

      csv = CSV.parse(response.body, headers: true)
      local_authorities = csv.map { it["Local Authority"] }
      expect(local_authorities).to contain_exactly(
        "Test Authority 201",
        "Unknown Local Authority"
      )
    end

    it "includes consent columns in CSV" do
      team = Team.last
      programme = Programme.hpv
      team.programmes << programme
      session = create(:session, team:, programmes: [programme])

      patient1 = create(:patient, session:, year_group: 8)
      create(:consent, :given, patient: patient1, programme:, team:)
      PatientStatusUpdater.call(patient: patient1)

      patient2 = create(:patient, session:, year_group: 9)
      create(:consent, :refused, patient: patient2, programme:, team:)
      PatientStatusUpdater.call(patient: patient2)

      refresh_reporting_views!

      request.headers["Accept"] = "text/csv"
      get :index, params: { group: "year_group" }, format: :csv

      expect(response).to have_http_status(:ok)

      csv = CSV.parse(response.body, headers: true)
      expect(csv.headers).to include(
        "Consent Given",
        "No Consent",
        "Consent No Response",
        "Consent Refused",
        "Consent Conflicts"
      )

      year_8_row = csv.find { it["Year Group"] == "8" }
      year_9_row = csv.find { it["Year Group"] == "9" }

      expect(year_8_row["Consent Given"]).to eq("1")
      expect(year_8_row["Consent Refused"]).to eq("0")

      expect(year_9_row["Consent Given"]).to eq("0")
      expect(year_9_row["Consent Refused"]).to eq("1")
    end
  end

  describe "Dashboard acceptance criteria" do
    let(:team) { Team.last }
    let(:cohort) { parsed_response["cohort"] }
    let(:vaccinated) { parsed_response["vaccinated"] }
    let(:not_vaccinated) { parsed_response["not_vaccinated"] }
    let(:vaccinations_given) { parsed_response["vaccinations_given"] }
    let(:monthly_vaccinations_given) do
      parsed_response["monthly_vaccinations_given"]
    end
    let(:hpv_programme) { Programme.hpv }
    let(:hpv_session) { create(:session, team:, programmes: [hpv_programme]) }
    let(:flu_programme) { Programme.flu }
    let(:flu_session) { create(:session, team:, programmes: [flu_programme]) }
    let(:menacwy_programme) { Programme.menacwy }
    let(:menacwy_session) do
      create(:session, team:, programmes: [menacwy_programme])
    end
    let(:td_ipv_programme) { Programme.td_ipv }
    let(:td_ipv_session) do
      create(:session, team:, programmes: [td_ipv_programme])
    end

    before do
      team.programmes << hpv_programme
      team.programmes << flu_programme
      team.programmes << menacwy_programme
      team.programmes << td_ipv_programme
    end

    def refresh_and_get_totals(programme_type: "hpv")
      refresh_reporting_views!
      get :index, params: { programme: programme_type }
      expect(response).to have_http_status(:ok)
    end

    it "child vaccinated by SAIS" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 1, "community_count" => 0 }
      )

      monthly =
        monthly_vaccinations_given.find do
          it["year"] == Time.current.year &&
            it["month"] == Date::MONTHNAMES[Time.current.month]
        end
      expect(monthly).to be_present
      expect(monthly["school_count"]).to eq(1)
      expect(monthly["community_count"]).to eq(0)
    end

    it "counts vaccination in correct month when performed during BST" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.zone.local(2024, 9, 1, 0, 30) # 00:30 BST = 23:30 UTC (Aug 31)
      )

      refresh_and_get_totals

      monthly =
        monthly_vaccinations_given.find do
          it["year"] == 2024 && it["month"] == "September"
        end
      expect(monthly).to be_present,
      "Expected vaccination to be counted in September, not August"
      expect(monthly["school_count"]).to eq(1)
      expect(monthly["community_count"]).to eq(0)
    end

    it "child archived after being vaccinated by SAIS" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals
      initial_response = JSON.parse(response.body)

      create(:archive_reason, patient:, team:, type: "moved_out_of_area")

      refresh_and_get_totals
      final_response = JSON.parse(response.body)

      expect(final_response["cohort"]).to eq(initial_response["cohort"] - 1)
      expect(final_response["vaccinated"]).to eq(
        initial_response["vaccinated"] - 1
      )
      expect(final_response["not_vaccinated"]).to eq(
        initial_response["not_vaccinated"]
      )
      expect(final_response["vaccinations_given"]).to eq(
        initial_response["vaccinations_given"]
      )
      expect(final_response["monthly_vaccinations_given"]).to eq(
        initial_response["monthly_vaccinations_given"]
      )
    end

    it "child deceased after being vaccinated by SAIS" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals
      initial_response = JSON.parse(response.body)

      patient.update!(date_of_death: Date.current)

      refresh_and_get_totals
      final_response = JSON.parse(response.body)

      expect(final_response["cohort"]).to eq(initial_response["cohort"] - 1)
      expect(final_response["vaccinated"]).to eq(
        initial_response["vaccinated"] - 1
      )
      expect(final_response["not_vaccinated"]).to eq(
        initial_response["not_vaccinated"]
      )
      expect(final_response["vaccinations_given"]).to eq(
        initial_response["vaccinations_given"]
      )
      expect(final_response["monthly_vaccinations_given"]).to eq(
        initial_response["monthly_vaccinations_given"]
      )
    end

    it "historic hpv record uploaded" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: nil,
        source: "historical_upload",
        outcome: "administered",
        performed_at: 1.year.ago
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "current hpv record uploaded" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: nil,
        source: "historical_upload",
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "historic flu record uploaded" do
      patient = create(:patient, session: flu_session)
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "historical_upload",
        outcome: "administered",
        performed_at: 1.year.ago
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)

      # flu is seasonal so vaccinations from a previous year don't count
      expect(vaccinated).to eq(0)
      expect(not_vaccinated).to eq(1)

      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "child already had vaccination" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        :already_had,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "vaccination imported from FHIR API" do
      patient = create(:patient, session: flu_session)

      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "nhs_immunisations_api",
        nhs_immunisations_api_identifier_system: "ABC",
        nhs_immunisations_api_identifier_value: "123",
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "already had and FHIR API import" do
      patient = create(:patient, session: flu_session)

      create(
        :vaccination_record,
        :already_had,
        patient:,
        programme: flu_programme,
        session: flu_session,
        performed_at: Time.current
      )
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "nhs_immunisations_api",
        nhs_immunisations_api_identifier_system: "ABC",
        nhs_immunisations_api_identifier_value: "123",
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "ineligible vaccination imported from FHIR API" do
      patient = create(:patient, session: flu_session)

      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "nhs_immunisations_api",
        nhs_immunisations_api_identifier_system: "ABC",
        nhs_immunisations_api_identifier_value: "123",
        outcome: "administered",
        performed_at: 1.year.ago
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      # flu is seasonal so vaccinations from a previous year don't count
      expect(vaccinated).to eq(0)
      expect(not_vaccinated).to eq(1)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "child refuses vaccination" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "refused",
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(0)
      expect(not_vaccinated).to eq(1)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "parent refuses consent" do
      patient = create(:patient, session: flu_session)
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "consent_refusal",
        outcome: "refused",
        performed_at: Time.current
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(0)
      expect(not_vaccinated).to eq(1)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "parent refuses consent claiming already vaccinated (consent only)" do
      patient = create(:patient, session: flu_session)
      create(
        :consent,
        :refused,
        patient:,
        programme: flu_programme,
        team:,
        reason_for_refusal: "already_vaccinated"
      )

      PatientStatusUpdater.call(patient:)
      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "parent refuses consent claiming already vaccinated and FHIR API import" do
      patient = create(:patient, session: flu_session)

      create(
        :consent,
        :refused,
        patient:,
        programme: flu_programme,
        team:,
        reason_for_refusal: "already_vaccinated"
      )
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: nil,
        source: "nhs_immunisations_api",
        nhs_immunisations_api_identifier_system: "ABC",
        nhs_immunisations_api_identifier_value: "123",
        outcome: "administered",
        performed_at: Time.current
      )

      PatientStatusUpdater.call(patient:)
      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "child moves in with eligible vaccination record" do
      other_team = create(:team, programmes: [flu_programme])
      other_session =
        create(:session, team: other_team, programmes: [flu_programme])

      patient = create(:patient, session: flu_session)
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: other_session,
        outcome: "administered",
        performed_at: 2.months.ago
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(1)
      expect(vaccinated).to eq(1)
      expect(not_vaccinated).to eq(0)
      expect(vaccinations_given).to eq(
        { "school_count" => 0, "community_count" => 0 }
      )
      expect(monthly_vaccinations_given).to be_empty
    end

    it "child moves out with eligible vaccination record" do
      other_org = create(:organisation)
      other_team =
        create(:team, programmes: [flu_programme], organisation: other_org)
      other_school = create(:gias_school, team: other_team)

      patient = create(:patient, session: flu_session)
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: flu_session,
        outcome: "administered",
        performed_at: Time.current # Current academic year for monthly breakdown
      )

      SchoolMove.create!(
        patient:,
        school: other_school,
        academic_year: AcademicYear.current,
        source: :cohort_import
      ).confirm!(user: create(:user))

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(0)
      expect(vaccinated).to eq(0)
      expect(not_vaccinated).to eq(0)

      # Child moved out, but vaccination was given by this team
      # so it should be counted as given
      expect(vaccinations_given).to eq(
        { "school_count" => 1, "community_count" => 0 }
      )
      monthly =
        monthly_vaccinations_given.find do
          it["year"] == Time.current.year &&
            it["month"] == Date::MONTHNAMES[Time.current.month]
        end
      expect(monthly).to be_present
      expect(monthly["school_count"]).to eq(1)
      expect(monthly["community_count"]).to eq(0)
    end

    it "splits vaccinations given by school and community location" do
      school_patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient: school_patient,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.current
      )

      community_clinic =
        create(
          :community_clinic,
          team:,
          programmes: [hpv_programme],
          academic_year: AcademicYear.current
        )
      community_session =
        create(
          :session,
          team:,
          location: community_clinic,
          programmes: [hpv_programme]
        )
      community_patient = create(:patient, session: community_session)
      create(
        :vaccination_record,
        patient: community_patient,
        programme: hpv_programme,
        session: community_session,
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(vaccinations_given).to eq(
        { "school_count" => 1, "community_count" => 1 }
      )

      monthly =
        monthly_vaccinations_given.find do
          it["year"] == Time.current.year &&
            it["month"] == Date::MONTHNAMES[Time.current.month]
        end
      expect(monthly).to be_present
      expect(monthly["school_count"]).to eq(1)
      expect(monthly["community_count"]).to eq(1)
    end

    it "counts HPV cohort correctly across years 8 to 11" do
      create(:patient, session: hpv_session, year_group: 8)
      create(:patient, session: hpv_session, year_group: 8)
      create(:patient, session: hpv_session, year_group: 9)
      create(:patient, session: hpv_session, year_group: 10)
      create(:patient, session: hpv_session, year_group: 11)

      create(:patient, session: hpv_session, year_group: 7)
      create(:patient, session: hpv_session, year_group: 12)

      refresh_and_get_totals

      expect(cohort).to eq(5)
    end

    it "counts flu cohort correctly across reception to year 11" do
      create(:patient, session: flu_session, year_group: 0)
      create(:patient, session: flu_session, year_group: 1)
      create(:patient, session: flu_session, year_group: 5)
      create(:patient, session: flu_session, year_group: 11)

      create(:patient, session: flu_session, year_group: 12)
      create(:patient, session: flu_session, year_group: 13)

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(4)
    end

    it "counts MenACWY cohort correctly across years 9 to 11" do
      create(:patient, session: menacwy_session, year_group: 9)
      create(:patient, session: menacwy_session, year_group: 10)
      create(:patient, session: menacwy_session, year_group: 11)

      create(:patient, session: menacwy_session, year_group: 8)
      create(:patient, session: menacwy_session, year_group: 12)

      refresh_and_get_totals(programme_type: "menacwy")

      expect(cohort).to eq(3)
    end

    it "counts Td/IPV cohort correctly across years 9 to 11" do
      create(:patient, session: td_ipv_session, year_group: 9)
      create(:patient, session: td_ipv_session, year_group: 10)
      create(:patient, session: td_ipv_session, year_group: 11)

      create(:patient, session: td_ipv_session, year_group: 8)
      create(:patient, session: td_ipv_session, year_group: 12)

      refresh_and_get_totals(programme_type: "td_ipv")

      expect(cohort).to eq(3)
    end

    it "counts year 12 students when session location has year 12 enabled" do
      send_location =
        create(
          :gias_school,
          gias_year_groups: (0..12).to_a,
          team:,
          programmes: [flu_programme],
          academic_year: AcademicYear.current
        )
      send_session =
        create(
          :session,
          location: send_location,
          team:,
          programmes: [flu_programme]
        )

      create(
        :location_programme_year_group,
        location: send_location,
        programme: flu_programme,
        year_group: 12,
        academic_year: AcademicYear.current
      )

      create(:patient, session: send_session, year_group: 11)
      create(:patient, session: send_session, year_group: 12)

      create(:patient, session: flu_session, year_group: 12)

      refresh_and_get_totals(programme_type: "flu")

      expect(cohort).to eq(2)
    end

    it "does not count year 12 students without SEND school enablement" do
      create(:patient, session: hpv_session, year_group: 12)
      create(:patient, session: flu_session, year_group: 12)
      create(:patient, session: menacwy_session, year_group: 12)
      create(:patient, session: td_ipv_session, year_group: 12)

      refresh_and_get_totals(programme_type: "hpv")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "flu")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "menacwy")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "td_ipv")
      expect(cohort).to eq(0)
    end

    it "does not count year 7 students for HPV, MenACWY and Td/IPV" do
      create(:patient, session: hpv_session, year_group: 7)
      create(:patient, session: menacwy_session, year_group: 7)
      create(:patient, session: td_ipv_session, year_group: 7)

      refresh_and_get_totals(programme_type: "hpv")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "menacwy")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "td_ipv")
      expect(cohort).to eq(0)
    end

    it "does not count year 8 students for MenACWY and Td/IPV" do
      create(:patient, session: menacwy_session, year_group: 8)
      create(:patient, session: td_ipv_session, year_group: 8)

      refresh_and_get_totals(programme_type: "menacwy")
      expect(cohort).to eq(0)

      refresh_and_get_totals(programme_type: "td_ipv")
      expect(cohort).to eq(0)
    end

    it "counts children with consent given" do
      patient = create(:patient, session: hpv_session)
      create(:consent, :given, patient:, programme: hpv_programme, team:)

      PatientStatusUpdater.call(patient:)
      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(parsed_response["consent_given"]).to eq(1)
      expect(parsed_response["consent_no_response"]).to eq(0)
    end

    it "counts children with no consent response" do
      patient =
        create(:patient, session: hpv_session, parents: [create(:parent)])

      create(
        :consent_notification,
        :request,
        patient:,
        session: hpv_session,
        programmes: [hpv_programme]
      )

      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(parsed_response["consent_given"]).to eq(0)
      expect(parsed_response["consent_no_response"]).to eq(1)
    end

    it "counts children with conflicting consent" do
      patient = create(:patient, session: hpv_session)
      parent1 = create(:parent)
      parent2 = create(:parent)
      create(:parent_relationship, patient:, parent: parent1)
      create(:parent_relationship, patient:, parent: parent2)

      create(
        :consent,
        :given,
        patient:,
        programme: hpv_programme,
        team:,
        parent: parent1
      )
      create(
        :consent,
        :refused,
        patient:,
        programme: hpv_programme,
        team:,
        parent: parent2
      )

      PatientStatusUpdater.call(patient:)
      refresh_and_get_totals

      expect(cohort).to eq(1)
      expect(parsed_response["consent_conflicts"]).to eq(1)
    end

    it "counts patient in current year category only when vaccinated both years" do
      patient = create(:patient, session: hpv_session)
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: nil,
        source: "historical_upload",
        outcome: "administered",
        performed_at: 1.year.ago
      )
      create(
        :vaccination_record,
        patient:,
        programme: hpv_programme,
        session: hpv_session,
        outcome: "administered",
        performed_at: Time.current
      )

      refresh_and_get_totals

      expect(vaccinated).to eq(1)
    end

    it "does not count previous flu vaccination from team session" do
      previous_flu_session =
        create(
          :session,
          team:,
          programmes: [flu_programme],
          date: 1.year.ago.to_date
        )
      patient = create(:patient, session: flu_session)
      create(
        :vaccination_record,
        patient:,
        programme: flu_programme,
        session: previous_flu_session,
        outcome: "administered",
        performed_at: 1.year.ago
      )

      refresh_and_get_totals(programme_type: "flu")

      expect(vaccinated).to eq(0)
    end
  end
end
