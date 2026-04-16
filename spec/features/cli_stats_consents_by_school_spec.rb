# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis stats consents-by-school", type: :integration do
  context "when organisation has consent data" do
    it "displays consent statistics and handles filtering" do
      given_organisation_has_consent_data

      when_i_run_the_command
      then_i_see_consent_statistics_for_all_programmes

      when_i_run_the_command_with_flu_programme
      then_i_see_consent_statistics_for_flu_only

      when_i_run_the_command_with_previous_academic_year
      then_i_see_consent_statistics_for_previous_year_only

      when_i_run_the_command_with_team_filtering
      then_i_see_consent_statistics_for_team_only
    end
  end

  context "when organisation does not exist" do
    it "displays error message" do
      when_i_run_the_command_with_invalid_organisation
      then_i_see_organisation_not_found_error
    end
  end

  context "when team does not exist" do
    it "displays error message" do
      given_organisation_exists
      when_i_run_the_command_with_invalid_team
      then_i_see_team_not_found_error
    end
  end

  private

  def command(*args)
    Dry::CLI.new(MavisCLI).call(
      arguments: ["stats", "consents-by-school", *args]
    )
  end

  def given_organisation_has_consent_data
    @organisation = create(:organisation, ods_code: "TEST003")
    programme_flu = Programme.flu
    programme_hpv = Programme.hpv

    programmes = [programme_flu, programme_hpv]

    @team_a =
      create(
        :team,
        organisation: @organisation,
        workgroup: "ImmunisationNorth",
        programmes:
      )
    @team_b =
      create(
        :team,
        organisation: @organisation,
        workgroup: "ImmunisationSouth",
        programmes:
      )

    school1 =
      create(:gias_school, name: "Primary School", team: @team_a, programmes:)
    school2 =
      create(:gias_school, name: "Secondary School", team: @team_b, programmes:)

    school1.import_year_groups_from_gias!(academic_year: AcademicYear.previous)
    school1.import_default_programme_year_groups!(
      programmes,
      academic_year: AcademicYear.previous
    )

    session1 =
      create(
        :session,
        team: @team_a,
        location: school1,
        programmes: [programme_flu],
        academic_year: AcademicYear.current,
        send_consent_requests_at: 10.days.ago
      )

    session2 =
      create(
        :session,
        team: @team_b,
        location: school2,
        programmes: [programme_hpv],
        academic_year: AcademicYear.current,
        send_consent_requests_at: 8.days.ago
      )

    session3 =
      create(
        :session,
        team: @team_a,
        location: school1,
        programmes: [programme_flu, programme_hpv],
        academic_year: AcademicYear.current,
        send_consent_requests_at: 12.days.ago
      )

    session_prev_year =
      create(
        :session,
        team: @team_a,
        location: school1,
        programmes: [programme_flu],
        academic_year: AcademicYear.previous,
        date: Date.new(AcademicYear.previous, 12, 15),
        send_consent_requests_at: Date.new(AcademicYear.previous, 12, 1)
      )

    patient1 = create(:patient, team: @team_a)
    patient2 = create(:patient, team: @team_b)
    patient3 = create(:patient, team: @team_a)
    patient_prev =
      create(
        :patient,
        :consent_given_triage_not_needed,
        session: session_prev_year
      )

    create(:patient_location, session: session1, patient: patient1)
    create(:patient_location, session: session2, patient: patient2)
    create(:patient_location, session: session3, patient: patient3)

    create(
      :consent,
      :given,
      patient: patient1,
      programme: programme_flu,
      submitted_at: 8.days.ago,
      created_at: 8.days.ago
    )

    create(
      :consent,
      :refused,
      patient: patient2,
      programme: programme_hpv,
      submitted_at: 6.days.ago,
      created_at: 6.days.ago
    )

    create(
      :consent,
      :given,
      patient: patient3,
      programme: programme_flu,
      submitted_at: 10.days.ago,
      created_at: 10.days.ago
    )

    create(
      :consent,
      :given,
      patient: patient_prev,
      programme: programme_flu,
      submitted_at: Date.new(AcademicYear.previous, 12, 5),
      created_at: Date.new(AcademicYear.current, 12, 5)
    )
  end

  def given_organisation_exists
    @organisation = create(:organisation, ods_code: "TEST004")
    @team = create(:team, organisation: @organisation, name: "Valid Team")
  end

  def when_i_run_the_command
    @output = capture_output { command("--ods_code", @organisation.ods_code) }
  end

  def when_i_run_the_command_with_flu_programme
    @output =
      capture_output do
        command("--ods_code", @organisation.ods_code, "--programme", "flu")
      end
  end

  def when_i_run_the_command_with_previous_academic_year
    previous_year = AcademicYear.previous
    @output =
      capture_output do
        command(
          "--ods_code",
          @organisation.ods_code,
          "--academic_year",
          previous_year.to_s
        )
      end
  end

  def when_i_run_the_command_with_team_filtering
    @output =
      capture_output do
        command(
          "--ods_code",
          @organisation.ods_code,
          "--workgroup",
          "ImmunisationNorth"
        )
      end
  end

  def when_i_run_the_command_with_invalid_organisation
    @output = capture_error { command("--ods_code", "INVALID123") }
  end

  def when_i_run_the_command_with_invalid_team
    @output =
      capture_error do
        command(
          "--ods_code",
          @organisation.ods_code,
          "--workgroup",
          "InvalidTeamName"
        )
      end
  end

  def then_i_see_consent_statistics_for_all_programmes
    expect(@output).to include(
      "Filtering by organisation: #{@organisation.ods_code}"
    )
    expect(@output).to include(
      "Filtering by all teams: ImmunisationNorth, ImmunisationSouth"
    )
    expect(@output).to include("--- Consent Responses by Date ---")
    expect(@output).to include(
      "--- Consent Responses by Days Since Request ---"
    )
    expect(@output).to include("Primary School")
    expect(@output).to include("Secondary School")
    expect(@output).to include("Cohort")
    expect(@output).to match(/\d{4}-\d{2}-\d{2}/)
  end

  def then_i_see_consent_statistics_for_flu_only
    expect(@output).to include(
      "Filtering by organisation: #{@organisation.ods_code}"
    )
    expect(@output).to include("--- Consent Responses by Date ---")
    expect(@output).to include(
      "--- Consent Responses by Days Since Request ---"
    )
    expect(@output).to include("Primary School")
    expect(@output).to include("Cohort")
    expect(@output).to include("Date consent requests sent")
    expect(@output).to match(/\d{4}-\d{2}-\d{2}/)

    expect(@output).not_to include("Secondary School")
  end

  def then_i_see_consent_statistics_for_previous_year_only
    expect(@output).to include("--- Consent Responses by Date ---")
    expect(@output).to include(
      "--- Consent Responses by Days Since Request ---"
    )

    prev_year_consent_date =
      Date.new(AcademicYear.previous, 12, 5).strftime("%Y-%m-%d")
    prev_year_request_date =
      Date.new(AcademicYear.previous, 12, 1).strftime("%Y-%m-%d")

    expect(@output).to include(prev_year_consent_date)
    expect(@output).to include(prev_year_request_date)

    current_year_dates =
      [8.days.ago, 6.days.ago, 10.days.ago].map { |d| d.strftime("%Y-%m-%d") }
    current_year_dates.each { |date| expect(@output).not_to include(date) }
  end

  def then_i_see_consent_statistics_for_team_only
    expect(@output).to include("Filtering by team: ImmunisationNorth")
    expect(@output).to include("Primary School")
    expect(@output).not_to include("Secondary School")
    expect(@output).not_to include("ImmunisationSouth")
    expect(@output).to include("Cohort")
    expect(@output).to include("--- Consent Responses by Date ---")
    expect(@output).to include(
      "--- Consent Responses by Days Since Request ---"
    )
  end

  def then_i_see_organisation_not_found_error
    expect(@output).to include(
      "Could not find organisation with ODS code 'INVALID123'"
    )
  end

  def then_i_see_team_not_found_error
    expect(@output).to include(
      "Could not find team 'InvalidTeamName' for organisation '#{@organisation.ods_code}'"
    )
  end
end
