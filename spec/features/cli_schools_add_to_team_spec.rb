# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools add-to-team" do
  context "when the team doesn't exist" do
    it "displays an error message" do
      when_i_run_the_command_expecting_an_error
      then_an_team_not_found_error_message_is_displayed
    end
  end

  context "when the subteam doesn't exist" do
    it "displays an error message" do
      given_the_team_exists

      when_i_run_the_command_expecting_an_error
      then_a_subteam_not_found_error_message_is_displayed
    end
  end

  context "when the school doesn't exist" do
    it "displays an error message" do
      given_the_team_exists
      and_the_subteam_exists

      when_i_run_the_command_expecting_an_error
      then_a_school_not_found_error_message_is_displayed
    end
  end

  context "when the school exists" do
    it "runs successfully" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists

      when_i_run_the_command
      then_the_school_is_added_to_the_team
    end
  end

  context "when the school belongs to another subteam" do
    it "displays a warning message" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists
      and_the_school_belongs_to_another_subteam

      when_i_run_the_command
      then_a_school_belongs_to_another_team_warning_message_is_displayed
      then_the_school_is_added_to_the_team
      and_the_school_remains_in_the_other_team_too
    end
  end

  context "when customising the programmes" do
    it "runs successfully" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists

      when_i_run_the_command_with_flu_only
      then_the_school_is_added_to_the_team_with_flu_only
    end
  end

  context "when the school has sites" do
    it "runs successfully when all sites are included" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists_with_multiple_sites

      when_i_run_the_command_with_all_sites
      then_all_sites_are_added_to_the_team
    end

    it "displays an error when using base URN instead of site URNs" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists_with_multiple_sites

      when_i_run_the_command_with_base_urn_expecting_an_error
      then_a_missing_sites_error_message_is_displayed
    end

    it "displays an error when not all sites are included" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists_with_multiple_sites

      when_i_run_the_command_with_partial_sites_expecting_an_error
      then_a_missing_site_b_error_message_is_displayed
    end

    it "allows partial sites when others are already in the team" do
      given_the_team_exists
      and_the_subteam_exists
      and_the_school_exists_with_multiple_sites
      and_site_b_already_belongs_to_the_team

      when_i_run_the_command_with_site_a_only
      then_site_a_is_added_to_the_team
    end
  end

  private

  def command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456]
    )
  end

  def command_with_flu_only
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456 --programmes flu]
    )
  end

  def given_the_team_exists
    @programmes = [Programme.flu, Programme.hpv]
    @team = create(:team, workgroup: "abc", programmes: @programmes)
  end

  def and_the_subteam_exists
    @subteam = create(:subteam, name: "Team", team: @team)
  end

  def and_the_school_exists
    @school = create(:gias_school, name: "School", urn: "123456")
  end

  def and_the_school_belongs_to_another_subteam
    @other_team = create(:team, name: "Other Team")
    @other_subteam = create(:subteam, name: "Other Subteam", team: @other_team)
    @school.attach_to_team!(
      @other_team,
      academic_year: AcademicYear.pending,
      subteam: @other_subteam
    )
  end

  def when_i_run_the_command
    @output = capture_error { command }
  end

  def when_i_run_the_command_with_flu_only
    @output = capture_error { command_with_flu_only }
  end

  def when_i_run_the_command_expecting_an_error
    @output = capture_error { command }
  end

  def then_an_team_not_found_error_message_is_displayed
    expect(@output).to include("Could not find team with workgroup abc.")
  end

  def then_a_subteam_not_found_error_message_is_displayed
    expect(@output).to include("Could not find subteam with name Team.")
  end

  def then_a_school_not_found_error_message_is_displayed
    expect(@output).to include("Could not find school with URN 123456.")
  end

  def then_a_school_belongs_to_another_team_warning_message_is_displayed
    expect(@output).to include("123456 previously belonged to Other Subteam.")
  end

  def then_the_school_is_added_to_the_team
    expect(@team.gias_schools).to include(@school)
    expect(@school.programmes).to eq(@programmes)
  end

  def then_the_school_is_added_to_the_team_with_flu_only
    expect(@team.gias_schools).to include(@school)
    expect(@school.programmes).to contain_exactly(@programmes.first)
  end

  def and_the_school_remains_in_the_other_team_too
    expect(@other_team.gias_schools).to include(@school)
  end

  def and_the_school_exists_with_multiple_sites
    @school_main =
      create(:gias_school, name: "School", urn: "123456", site: nil)
    @school_site_a =
      create(:gias_school, name: "School Site A", urn: "123456", site: "A")
    @school_site_b =
      create(:gias_school, name: "School Site B", urn: "123456", site: "B")
  end

  def and_site_b_already_belongs_to_the_team
    @school_site_b.attach_to_team!(
      @team,
      academic_year: AcademicYear.pending,
      subteam: @subteam
    )
  end

  def command_with_base_urn
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456]
    )
  end

  def command_with_partial_sites
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456A]
    )
  end

  def command_with_all_sites
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456A 123456B]
    )
  end

  def command_with_site_a_only
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools add-to-team abc Team 123456A]
    )
  end

  def when_i_run_the_command_with_base_urn_expecting_an_error
    @output = capture_error { command_with_base_urn }
  end

  def when_i_run_the_command_with_partial_sites_expecting_an_error
    @output = capture_error { command_with_partial_sites }
  end

  def when_i_run_the_command_with_all_sites
    @output = capture_error { command_with_all_sites }
  end

  def when_i_run_the_command_with_site_a_only
    @output = capture_error { command_with_site_a_only }
  end

  def then_a_missing_sites_error_message_is_displayed
    expect(@output).to include("URN 123456 has multiple sites in the database")
    expect(@output).to include("123456A")
    expect(@output).to include("123456B")
  end

  def then_a_missing_site_b_error_message_is_displayed
    expect(@output).to include("Missing site 123456B")
  end

  def then_all_sites_are_added_to_the_team
    expect(@team.gias_schools).to include(@school_site_a)
    expect(@team.gias_schools).to include(@school_site_b)
    expect(@team.gias_schools).not_to include(@school_main)
  end

  def then_site_a_is_added_to_the_team
    expect(@team.gias_schools).to include(@school_site_a)
    expect(@team.gias_schools).to include(@school_site_b) # already was in team
  end
end
