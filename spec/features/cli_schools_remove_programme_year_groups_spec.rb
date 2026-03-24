# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools remove-programme-year-group" do
  context "when the school doesn't exist" do
    it "displays an error message" do
      when_i_run_the_command_expecting_an_error
      then_a_school_not_found_error_message_is_displayed
    end
  end

  context "when the programme doesn't exist" do
    it "displays an error message" do
      given_the_school_exists

      when_i_run_the_command_with_invalid_programme
      then_a_programme_not_found_error_message_is_displayed
    end
  end

  context "when the school and programme exists" do
    it "runs successfully" do
      given_the_school_exists
      and_the_programme_exists
      and_existing_programme_year_groups_exist

      when_i_run_the_command
      then_the_year_groups_are_removed_from_the_school
    end
  end

  private

  def command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools remove-programme-year-group 123456 flu 9 10 11]
    )
  end

  def command_with_invalid_programme
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools remove-programme-year-group 123456 invalid 9 10 11]
    )
  end

  def given_the_school_exists
    @school = create(:gias_school, urn: "123456")
  end

  def and_the_programme_exists
    @programme = Programme.flu
  end

  def and_existing_programme_year_groups_exist
    (0..11).to_a.each do |year_group|
      location_year_group =
        @school.location_year_groups.find_or_create_by!(
          value: year_group,
          academic_year: AcademicYear.current
        )
      location_year_group.location_programme_year_groups.create!(
        programme_type: @programme.type
      )
    end
  end

  def when_i_run_the_command
    @output = capture_error { command }
  end

  def when_i_run_the_command_expecting_an_error
    @output = capture_error { command }
  end

  def when_i_run_the_command_with_invalid_programme
    @output = capture_error { command_with_invalid_programme }
  end

  def then_a_school_not_found_error_message_is_displayed
    expect(@output).to include("Could not find school.")
  end

  def then_a_programme_not_found_error_message_is_displayed
    expect(@output).to include("Could not find programme.")
  end

  def then_the_year_groups_are_removed_from_the_school
    year_groups =
      @school
        .location_programme_year_groups
        .for_programme(@programme)
        .pluck_year_groups

    expect(year_groups).not_to include(9)
    expect(year_groups).not_to include(10)
    expect(year_groups).not_to include(11)
  end
end
