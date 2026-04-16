# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis teams add-programme" do
  context "when the team doesn't exist" do
    it "displays an error message" do
      when_i_run_the_command_expecting_an_error
      then_a_team_not_found_error_message_is_displayed
    end
  end

  context "when the programme doesn't exist" do
    it "displays an error message" do
      given_the_team_exists

      when_i_run_the_command_with_invalid_programme
      then_a_programme_not_found_error_message_is_displayed
    end
  end

  context "when the programme exists" do
    it "runs successfully" do
      given_the_team_exists
      and_is_already_set_up_for_hpv
      and_the_programme_exists

      when_i_run_the_command
      then_only_the_new_programme_is_added_to_the_team
    end
  end

  private

  def command
    Dry::CLI.new(MavisCLI).call(arguments: %w[teams add-programme abc flu])
  end

  def command_with_invalid_programme
    Dry::CLI.new(MavisCLI).call(arguments: %w[teams add-programme abc invalid])
  end

  def given_the_team_exists
    @team = create(:team, workgroup: "abc")
    @school = create(:gias_school, :secondary, team: @team)
  end

  def and_is_already_set_up_for_hpv
    @team.programmes << Programme.hpv
  end

  def and_the_programme_exists
    @programme = Programme.flu
  end

  def when_i_run_the_command
    @output = capture_output { command }
  end

  def when_i_run_the_command_expecting_an_error
    @output = capture_error { command }
  end

  def when_i_run_the_command_with_invalid_programme
    @output = capture_error { command_with_invalid_programme }
  end

  def then_a_team_not_found_error_message_is_displayed
    expect(@output).to include("Could not find team.")
  end

  def then_a_programme_not_found_error_message_is_displayed
    expect(@output).to include("Could not find programme.")
  end

  def then_only_the_new_programme_is_added_to_the_team
    @team.reload

    expect(@team.programmes).to include(@programme)

    location_programme_year_groups =
      @school.location_programme_year_groups.for_programme(@programme)
    expect(location_programme_year_groups.count).to eq(5)
  end
end
