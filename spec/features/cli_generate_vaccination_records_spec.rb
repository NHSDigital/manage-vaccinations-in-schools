# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis generate vaccination-records" do
  it "generates vaccination records in all sessions" do
    given_a_team_with_sessions_exists
    and_there_are_patients_in_each_session
    when_i_generate_four_vaccination_records
    then_four_vaccination_records_are_created
  end

  it "generates vaccination records" do
    given_a_team_with_sessions_exists
    and_there_is_a_patient_in_each_session
    when_i_generate_a_vaccination_record_for_a_specific_session
    then_the_administered_vaccination_records_is_created_for_that_session
  end

  def given_a_team_with_sessions_exists
    @programme = Programme.hpv
    @team = create(:team, programmes: [@programme])
    create(
      :batch,
      :not_expired,
      team: @team,
      vaccine: @programme.vaccines.active.first
    )

    @session1 =
      create(
        :session,
        team: @team,
        programmes: [@programme],
        location: @team.generic_clinic
      )
    @session2 = create(:session, team: @team, programmes: [@programme])
    @session3 = create(:session, team: @team, programmes: [@programme])
    @session4 = create(:session, team: @team, programmes: [@programme])
  end

  def and_there_are_patients_in_each_session
    [@session1, @session2, @session3, @session4].each do |session|
      create_list(
        :patient,
        3,
        :consent_given_triage_not_needed,
        team: @team,
        session:,
        programmes: [@programme]
      )
    end
  end

  def and_there_is_a_patient_in_each_session
    create(
      :patient,
      :consent_given_triage_not_needed,
      team: @team,
      session: @session1,
      programmes: [@programme]
    )
    create(
      :patient,
      :consent_given_triage_not_needed,
      team: @team,
      session: @session2,
      programmes: [@programme]
    )
  end

  def when_i_generate_four_vaccination_records
    Dry::CLI.new(MavisCLI).call(
      arguments: [
        "generate",
        "vaccination-records",
        "-w",
        @team.workgroup,
        "-p",
        @programme.type,
        "-A",
        "4"
      ]
    )
  end

  def when_i_generate_a_vaccination_record_for_a_specific_session
    @vaccination_records_count_before = @team.vaccination_records.count

    Dry::CLI.new(MavisCLI).call(
      arguments: [
        "generate",
        "vaccination-records",
        "-w",
        @team.workgroup,
        "-p",
        @programme.type,
        "-s",
        @session1.id.to_s,
        "-A",
        "1"
      ]
    )
  end

  def then_four_vaccination_records_are_created
    expect(vaccination_records_for(@team).count).to eq 4
  end

  def then_the_administered_vaccination_records_is_created_for_that_session
    expect(vaccination_records_for(@session1).count).to eq 1
    expect(vaccination_records_for(@session2).count).to eq 0
  end

  def vaccination_records_for(team_or_session)
    team_or_session.reload.patients.has_programme_status(
      Patient::ProgrammeStatus::VACCINATED_STATUSES.keys,
      programme: @programme,
      academic_year: AcademicYear.current
    )
  end
end
