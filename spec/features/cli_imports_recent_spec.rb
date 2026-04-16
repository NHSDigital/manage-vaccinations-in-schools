# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis imports recent" do
  scenario "shows both class and cohort imports by default" do
    given_there_imports
    when_i_run_the_recent_patient_imports_command
    then_i_should_see_both_import_types
  end

  scenario "filters to show only class imports" do
    given_there_imports
    when_i_run_the_command_filtered_by_type("class")
    then_i_should_see_only_class_imports
  end

  scenario "filters to show only cohort imports" do
    given_there_imports
    when_i_run_the_command_filtered_by_type("cohort")
    then_i_should_see_only_cohort_imports
  end

  scenario "filters to show only immunisation imports" do
    given_there_imports
    when_i_run_the_command_filtered_by_type("immunisation")
    then_i_should_see_only_immunisation_imports
  end

  scenario "limits the number of imports shown across both types" do
    given_there_are_multiple_class_and_cohort_imports
    when_i_run_the_command_with_a_number_limit
    then_i_should_see_a_limited_number_of_imports
  end

  scenario "filters by organisation across both import types" do
    given_there_are_imports_in_different_organisations
    when_i_run_the_command_filtered_by_organisation
    then_i_should_see_imports_for_that_organisation_only
  end

  scenario "filters by workgroup across both import types" do
    given_there_are_imports_in_different_workgroups
    when_i_run_the_command_filtered_by_workgroup
    then_i_should_see_imports_for_that_workgroup_only
  end

  scenario "sorts imports by created_at across both types" do
    given_there_are_interleaved_class_and_cohort_imports
    when_i_run_the_recent_patient_imports_command
    then_i_should_see_imports_sorted_by_creation_date
  end

  def given_there_imports
    team = create(:team, workgroup: "test_team")
    location = create(:gias_school, team:)

    @class_import = create(:class_import, :processed, team:, location:)
    @cohort_import = create(:cohort_import, :processed, team:)
    @immunisation_import = create(:immunisation_import, :processed, team:)
  end

  def given_there_are_multiple_class_and_cohort_imports
    team = create(:team, workgroup: "multi_team")
    location = create(:gias_school, team:)

    # Create 3 of each type with time travel to ensure proper ordering
    freeze_time do
      create(:class_import, :processed, team:, location:)
      travel 1.minute
      create(:class_import, :processed, team:, location:)
      travel 1.minute
      create(:class_import, :processed, team:, location:)
      travel 1.minute
      @oldest_import = create(:cohort_import, :processed, team:)
      travel 1.minute
      @middle_aged_import = create(:cohort_import, :processed, team:)
      travel 1.minute
      @youngest_import = create(:cohort_import, :processed, team:)
    end
  end

  def given_there_are_imports_in_different_organisations
    organisation1 = create(:organisation, ods_code: "ORG1")
    organisation2 = create(:organisation, ods_code: "ORG2")
    team1 = create(:team, organisation: organisation1, workgroup: "team1")
    team2 = create(:team, organisation: organisation2, workgroup: "team2")
    location = create(:gias_school, team: team1)

    create(:class_import, :processed, team: team1, location:)
    create(:cohort_import, :processed, team: team1)
    create(:cohort_import, :processed, team: team2)
  end

  def given_there_are_imports_in_different_workgroups
    organisation = create(:organisation)
    team1 = create(:team, organisation:, workgroup: "wg1")
    team2 = create(:team, organisation:, workgroup: "wg2")
    location = create(:gias_school, team: team1)

    create(:class_import, :processed, team: team1, location:)
    create(:cohort_import, :processed, team: team1)
    create(:cohort_import, :processed, team: team2)
  end

  def given_there_are_interleaved_class_and_cohort_imports
    team = create(:team, workgroup: "interleaved")
    location = create(:gias_school, team:)

    freeze_time do
      @oldest = create(:cohort_import, :processed, team:)
      travel 1.hour
      @middle = create(:class_import, :processed, team:, location:)
      travel 1.hour
      @newest = create(:cohort_import, :processed, team:)
    end
  end

  def when_i_run_the_recent_patient_imports_command
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(arguments: %w[imports recent --once])
      end
  end

  def when_i_run_the_command_filtered_by_type(type)
    type_option =
      case type
      when "class"
        "--class-imports"
      when "cohort"
        "--cohort-imports"
      when "immunisation"
        "--immunisation-imports"
      else
        raise ArgumentError, "Invalid type: #{type}"
      end

    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: ["imports", "recent", "--once", type_option]
        )
      end
  end

  def when_i_run_the_command_with_a_number_limit
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[imports recent --once --number 3]
        )
      end
  end

  def when_i_run_the_command_filtered_by_organisation
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[imports recent --once --organisations ORG1]
        )
      end
  end

  def when_i_run_the_command_filtered_by_workgroup
    @output =
      capture_output do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[imports recent --once --workgroups wg1]
        )
      end
  end

  def then_i_should_see_both_import_types
    expect(@output).to include(/^. \s cla \S+ \s+ #{@class_import.id}/x)
    expect(@output).to include(/^. \s coh \S+ \s+ #{@cohort_import.id}/x)
    expect(@output).to include(/^. \s imm \S+ \s+ #{@immunisation_import.id}/x)
  end

  def then_i_should_see_only_class_imports
    expect(@output).to include(/^. \s cla \S+ \s+ #{@class_import.id}/x)
    expect(@output).not_to include(/^. \s coh \S+ \s+ #{@cohort_import.id}/x)
    expect(@output).not_to include(
      /^. \s imm \S+ \s+ #{@immunisation_import.id}/x
    )
  end

  def then_i_should_see_only_cohort_imports
    expect(@output).to include(/^. \s coh \S+ \s+ #{@cohort_import.id}/x)
    expect(@output).not_to include(/^. \s cla \S+ \s+ #{@class_import.id}/x)
    expect(@output).not_to include(
      /^. \s imm \S+ \s+ #{@immunisation_import.id}/x
    )
  end

  def then_i_should_see_only_immunisation_imports
    expect(@output).not_to include(/^. \s coh \S+ \s+ #{@cohort_import.id}/x)
    expect(@output).not_to include(/^. \s cla \S+ \s+ #{@class_import.id}/x)
    expect(@output).to include(/^. \s imm \S+ \s+ #{@immunisation_import.id}/x)
  end

  def then_i_should_see_a_limited_number_of_imports
    content_lines = @output.lines[2..-2]

    expect(content_lines.count).to eq(3)

    expect(content_lines[0]).to include(
      /^. \s coh \S+ \s+ #{@youngest_import.id} \b/x
    )
    expect(content_lines[1]).to include(
      /^. \s coh \S+ \s+ #{@middle_aged_import.id} \b/x
    )
    expect(content_lines[2]).to include(
      /^. \s coh \S+ \s+ #{@oldest_import.id} \b/x
    )
  end

  def then_i_should_see_imports_for_that_organisation_only
    expect(@output).to include("ORG1")
    expect(@output).not_to include("ORG2")
  end

  def then_i_should_see_imports_for_that_workgroup_only
    content_lines = @output.lines[2..-2]

    expect(content_lines).to include(/^. \s coh \S+ \s+ .* \b wg1/x)
    expect(content_lines).to include(/^. \s cla \S+ \s+ .* \b wg1/x)
    expect(content_lines).not_to include(/wg2/)
  end

  def then_i_should_see_imports_sorted_by_creation_date
    content_lines = @output.lines[2..-2]

    expect(content_lines[0]).to include(/^. \s coh \S+ \s+ #{@newest.id} \b/x)
    expect(content_lines[1]).to include(/^. \s cla \S+ \s+ #{@middle.id} \b/x)
    expect(content_lines[2]).to include(/^. \s coh \S+ \s+ #{@oldest.id} \b/x)
  end
end
