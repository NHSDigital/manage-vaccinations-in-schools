# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis teams onboard" do
  context "with a valid point of care configuration" do
    it "runs successfully" do
      given_programmes_and_schools_exist
      when_i_run_the_valid_command_for_a_point_of_care_team
      then_i_see_no_output
      and_a_new_team_is_created
      and_schools_are_added_to_the_team_appropriately
    end
  end

  context "with a valid national reporting configuration" do
    it "runs successfully" do
      given_programmes_and_schools_exist
      when_i_run_the_valid_command_for_a_national_reporting_team
      then_i_see_no_output
      and_a_new_team_is_created
    end
  end

  context "with an invalid configuration" do
    it "displays an error message" do
      given_programmes_and_schools_exist
      when_i_run_the_invalid_command
      then_i_see_an_error_message
    end
  end

  context "with a training configuration", :local_users do
    it "runs successfully" do
      given_programmes_and_schools_exist
      when_i_run_the_command_for_training
      then_i_see_no_output
      and_a_new_team_is_created
    end
  end

  context "with a training configuration and CIS2 is enabled" do
    it "runs successfully" do
      given_programmes_and_schools_exist
      when_i_run_the_command_for_training
      then_i_see_no_output
      and_a_new_team_is_created
    end
  end

  def command_with_valid_point_of_care_configuration
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[
        teams
        onboard
        spec/fixtures/files/onboarding/point_of_care_valid.yaml
      ]
    )
  end

  def command_with_valid_national_reporting_configuration
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[
        teams
        onboard
        spec/fixtures/files/onboarding/national_reporting_valid.yaml
      ]
    )
  end

  def command_with_invalid_configuration
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[teams onboard spec/fixtures/files/onboarding/invalid.yaml]
    )
  end

  def command_for_training
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[
        teams
        onboard
        --training
        --ods-code=EXAMPLE
        --workgroup=nhstrust
      ]
    )
  end

  def given_programmes_and_schools_exist
    Programme.hpv
    Programme.flu

    @school_a =
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "123456",
        name: "Existing School 1"
      )
    @school_b =
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "234567",
        name: "Existing School 2"
      )
    @school_c =
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "345678",
        name: "Existing School 3"
      )
    @school_d =
      create(
        :gias_school,
        :secondary,
        :open,
        urn: "456789",
        name: "Existing School 4"
      )
  end

  def when_i_run_the_valid_command_for_a_point_of_care_team
    @output = capture_output { command_with_valid_point_of_care_configuration }
  end

  def when_i_run_the_valid_command_for_a_national_reporting_team
    @output =
      capture_output { command_with_valid_national_reporting_configuration }
  end

  def when_i_run_the_invalid_command
    @output = capture_output { command_with_invalid_configuration }
  end

  def when_i_run_the_command_for_training
    @output = capture_output { command_for_training }
  end

  def then_i_see_no_output
    expect(@output).to be_empty
  end

  def and_a_new_team_is_created
    expect(Team.count).to eq(1)
  end

  def and_schools_are_added_to_the_team_appropriately
    expect(Team.last.gias_schools.count).to eq(6)
    school_b_sites = Location.where(urn: @school_b.urn).where.not(site: nil)
    school_d_sites = Location.where(urn: @school_d.urn).where.not(site: nil)
    expect(Team.last.gias_schools).to include(
      @school_a,
      @school_c,
      *school_b_sites,
      *school_d_sites
    )

    expect(school_b_sites.count).to eq(2)
    expect(school_b_sites.map { it.teams.count }).to eq([1, 1])
    expect(school_b_sites.map(&:name)).to eq(
      ["Existing School 2 (Site A)", "Existing School 2 (Site B)"]
    )
    expect(@school_b.teams).to be_empty

    expect(school_d_sites.count).to eq(2)
    expect(school_d_sites.map { it.teams.count }).to eq([1, 1])
    expect(school_d_sites.map(&:name)).to eq(
      ["Existing School 4 (Site A)", "Existing School 4 (Site B)"]
    )
    expect(school_d_sites.find_by(site: "B").address_line_1).to eq(
      "456 High St"
    )
    expect(@school_d.teams).to be_empty
  end

  def then_i_see_an_error_message
    expect(@output).to include("Programmes Choose at least one programme")
    expect(@output).to include(
      "Schools URN(s) 456789 cannot appear as both a regular school and a site"
    )
  end
end
