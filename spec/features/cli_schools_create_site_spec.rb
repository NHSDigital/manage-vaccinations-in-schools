# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools create-site" do
  context "when adding to team" do
    it "runs successfully" do
      given_a_school_exists
      when_i_run_the_command_with_add_to_team
      then_the_school_is_created
      and_the_school_is_added_to_team
    end
  end

  context "when not adding to team" do
    it "runs successfully" do
      given_a_school_exists
      when_i_run_the_command_without_add_to_team
      then_the_school_is_created
      and_the_school_is_not_added_to_team
    end
  end

  private

  def given_a_school_exists
    team = create(:team)
    subteam = create(:subteam, team:)
    @school =
      create(
        :gias_school,
        urn: "123456",
        name: "MainSchool",
        site: nil,
        team:,
        subteam:
      )
  end

  def add_to_team_command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools create-site 123456 SiteSchool A --add-to-team]
    )
  end

  def no_add_to_team_command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools create-site 123456 SiteSchool A]
    )
  end

  def when_i_run_the_command_with_add_to_team
    @output = capture_output { add_to_team_command }
  end

  def when_i_run_the_command_without_add_to_team
    @output = capture_output { no_add_to_team_command }
  end

  def then_the_school_is_created
    location = Location.find_by(urn: "123456", site: "A")
    expect(location.name).to eq("SiteSchool")
    expect(location.urn_and_site).to eq("123456A")
    expect(location.gias_establishment_number).to eq(
      @school.gias_establishment_number
    )
    expect(location.gias_local_authority_code).to eq(
      @school.gias_local_authority_code
    )
    expect(location.gias_phase).to eq(@school.gias_phase)
  end

  def and_the_school_is_added_to_team
    location = Location.find_by(urn: "123456", site: "A")
    expect(location.teams.count).to eq(1)
  end

  def and_the_school_is_not_added_to_team
    location = Location.find_by(urn: "123456", site: "A")
    expect(location.teams.count).to eq(0)
  end
end
