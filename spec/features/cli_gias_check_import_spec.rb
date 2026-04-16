# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis gias check_import" do
  it "counts the number of schools closed that have future sessions" do
    given_an_team_exists
    and_there_are_schools_with_future_sessions
    when_i_run_the_check_import_command
    then_i_should_see_the_correct_counts
  end

  def given_an_team_exists
    @programme = Programme.hpv
    @team = create(:team, ods_code: "A9A5A", programmes: [@programme])
  end

  def and_there_are_schools_with_future_sessions
    @school_with_future_session =
      create(
        :gias_school,
        name: "The Aldgate School",
        urn: "100000",
        gias_year_groups: (-1..6).to_a
      )
    @session_with_future_dates =
      create(
        :session,
        location: @school_with_future_session,
        date: Date.tomorrow,
        programmes: [@programme],
        team: @team
      )

    @successor_school =
      create(
        :gias_school,
        name: "The Aldgate Academy",
        urn: "100004",
        team: @team
      )

    @school2_with_future_session =
      create(
        :gias_school,
        name: "St Paul's Cathedral School",
        urn: "100002",
        gias_year_groups: (0..6).to_a
      )
    @session_with_future_dates =
      create(
        :session,
        location: @school2_with_future_session,
        date: Date.tomorrow,
        programmes: [@programme],
        team: @team
      )

    @school_without_future_session =
      create(
        :gias_school,
        name: "City of London School for Girls",
        urn: "100001",
        gias_year_groups: (3..13).to_a
      )
    @session_without_future_dates =
      create(
        :session,
        location: @school_without_future_session,
        date: Date.yesterday,
        programmes: [@programme],
        team: @team
      )
  end

  def when_i_run_the_check_import_command
    # This will exit if the command is not found. We could mock out Kernel.exit
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[
            gias
            check-import
            -i
            spec/fixtures/files/dfe-schools.zip
          ]
        )
      end
  end

  def then_i_should_see_the_correct_counts
    expect(@output).to include("New schools (total): 1")
    expect(@output).to include("Closed schools (total): 2")
    expect(@output).to include("Proposed to be closed schools (total): 1")

    expect(@output).to include("Existing schools with future sessions: 2")
    expect(@output).to include("That are closed in import: 1")
    expect(@output).to include("That have year group changes: 1")

    expect(@output).to include(
      "URNs of closed schools with future sessions:\n  100000 -> successor(s): 100004 (Team: #{@team.name})"
    )
    expect(@output).to include(
      "URNs of schools that will be closing, with future sessions:\n  100002"
    )
    expect(@output).to include(
      "URNs of schools with year group changes, with future sessions:\n  100002:" \
        "\n    Current:  [0, 1, 2, 3, 4, 5, 6]\n    New:      [0, 1, 2, 3, 4, 5, 6, 7, 8]"
    )
  end
end
