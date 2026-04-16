# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools remove-from-team" do
  context "when the team doesn't exist" do
    it "displays an error message" do
      when_i_run_the_command_expecting_an_error
      then_a_team_not_found_error_message_is_displayed
    end
  end

  context "when the subteam doesn't exist" do
    it "displays an error message" do
      given_the_team_exists

      when_i_run_the_command_expecting_an_error
      then_a_subteam_not_found_error_message_is_displayed
    end
  end

  context "when the schools don't exist" do
    it "displays an error message" do
      given_the_team_exists
      and_the_subteam_exists

      when_i_run_the_command_expecting_an_error
      then_a_school_not_found_error_message_is_displayed
    end
  end

  context "when the schools exist" do
    it "runs successfully" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_schools_exist

      when_i_run_the_command
      then_the_schools_are_removed_from_the_team
    end
  end

  context "when the school isn't in the specified team" do
    it "displays an error message" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_schools_exist_but_in_a_different_team

      when_i_run_the_command_expecting_an_error
      then_a_team_location_not_found_error_message_is_displayed
    end
  end

  private

  def given_the_team_exists
    @team = create(:team, workgroup: "TeamA")
  end

  def and_the_subteam_exists
    @subteam = create(:subteam, team: @team, name: "SubteamA")
  end

  def and_the_schools_exist
    @school_a =
      create(
        :gias_school,
        urn: "123456",
        name: "MainSchool",
        site: nil,
        team: @team,
        subteam: @subteam
      )
    @school_b =
      create(
        :gias_school,
        urn: "654321",
        name: "OtherSchool",
        site: nil,
        team: @team,
        subteam: @subteam
      )
    expect(@school_a.teams.count).to eq(1)
    expect(@school_b.teams.count).to eq(1)
  end

  def and_the_schools_exist_but_in_a_different_team
    @other_team = create(:team, workgroup: "TeamB")
    @school_a =
      create(
        :gias_school,
        urn: "123456",
        name: "MainSchool",
        site: nil,
        team: @other_team
      )
    @school_b =
      create(
        :gias_school,
        urn: "654321",
        name: "OtherSchool",
        site: nil,
        team: @other_team
      )
  end

  def command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[
        schools
        remove-from-team
        TeamA
        SubteamA
        123456
        654321
        --academic-year
        2025
      ]
    )
  end

  def when_i_run_the_command
    @output = capture_output { command }
  end

  def when_i_run_the_command_expecting_an_error
    @output = capture_error { command }
  end

  def then_a_team_not_found_error_message_is_displayed
    expect(@output).to include("Could not find team with workgroup TeamA")
  end

  def then_a_subteam_not_found_error_message_is_displayed
    expect(@output).to include("Could not find subteam with name SubteamA")
  end

  def then_a_school_not_found_error_message_is_displayed
    expect(@output).to include("Could not find school with URN 123456")
    expect(@output).to include("Could not find school with URN 654321")
  end

  def then_a_team_location_not_found_error_message_is_displayed
    expect(@output).to include("Could not find team location for URN 123456")
    expect(@output).to include("Could not find team location for URN 654321")
  end

  def then_the_schools_are_removed_from_the_team
    expect(@school_a.teams.count).to eq(0)
    expect(@school_b.teams.count).to eq(0)
  end
end
