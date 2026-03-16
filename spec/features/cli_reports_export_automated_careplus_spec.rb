# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis reports export-automated-careplus" do
  around { |example| travel_to(Date.new(2026, 3, 16)) { example.run } }

  let(:output_path) { Rails.root.join("tmp/test_automated_export.csv").to_s }

  before do
    allow(Reports::AutomatedCareplusExporter).to receive(:call).and_return(
      "csv content"
    )
  end

  context "with a valid organisation and single team" do
    it "exports the CSV and reports success" do
      given_an_organisation_with_a_single_team
      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--start_date=2025-09-01",
        "--end_date=2026-03-10",
        "--output=#{output_path}"
      )
      then_the_exporter_is_called_with(
        team: @team,
        academic_year: AcademicYear.current,
        start_date: Date.new(2025, 9, 1),
        end_date: Date.new(2026, 3, 10)
      )
      and_the_output_file_contains("csv content")
      and_the_success_message_is_displayed
    end
  end

  context "when the organisation does not exist" do
    it "warns and does not call the exporter" do
      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=UNKNOWN"
      )
      then_the_error_output_includes(
        "Could not find organisation with ODS code 'UNKNOWN'"
      )
      and_the_exporter_is_not_called
    end
  end

  context "when the organisation has multiple teams and no workgroup is given" do
    it "warns and does not call the exporter" do
      given_an_organisation_with_multiple_teams

      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=#{@organisation.ods_code}"
      )
      then_the_error_output_includes("has multiple teams")
      and_the_exporter_is_not_called
    end
  end

  context "when a workgroup is specified" do
    it "calls the exporter with the matching team" do
      given_an_organisation_with_multiple_teams

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--workgroup=#{@team.workgroup}",
        "--output=#{output_path}"
      )
      then_the_exporter_is_called_with(team: @team)
    end
  end

  context "when a custom academic year is specified" do
    it "passes the academic year to the exporter" do
      given_an_organisation_with_a_single_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--academic_year=2024",
        "--output=#{output_path}"
      )
      then_the_exporter_is_called_with(academic_year: 2024)
    end
  end

  context "when the team does not have CarePlus enabled" do
    it "warns and does not call the exporter" do
      given_an_organisation_with_a_team_without_careplus

      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=#{@organisation.ods_code}"
      )
      then_the_error_output_includes("does not have CarePlus enabled")
      and_the_exporter_is_not_called
    end
  end

  context "when the team has CarePlus enabled" do
    it "calls the exporter" do
      given_an_organisation_with_a_single_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--output=#{output_path}"
      )
      then_the_exporter_is_called_with(team: @team)
    end
  end

  private

  def command(*args)
    Dry::CLI.new(MavisCLI).call(
      arguments: ["reports", "export-automated-careplus", *args]
    )
  end

  def given_an_organisation_with_a_team_without_careplus
    @organisation = create(:organisation)
    create(:team, organisation: @organisation, programmes: Programme.all)
  end

  def given_an_organisation_with_a_single_team
    @organisation = create(:organisation)
    @team =
      create(
        :team,
        :with_careplus_enabled,
        organisation: @organisation,
        programmes: Programme.all
      )
  end

  def given_an_organisation_with_multiple_teams
    @organisation = create(:organisation)
    @team =
      create(
        :team,
        :with_careplus_enabled,
        organisation: @organisation,
        programmes: Programme.all
      )
    create(
      :team,
      :with_careplus_enabled,
      organisation: @organisation,
      programmes: Programme.all
    )
  end

  def when_i_run_the_command_with_options(*args)
    @output = capture_output { command(*args) }
  end

  def when_i_run_the_command_with_options_and_capture_error(*args)
    @error = capture_error { command(*args) }
  end

  def then_the_exporter_is_called_with(**kwargs)
    expect(Reports::AutomatedCareplusExporter).to have_received(:call).with(
      hash_including(**kwargs)
    )
  end

  def and_the_output_file_contains(content)
    expect(File.read(output_path)).to eq(content)
  end

  def and_the_success_message_is_displayed
    expect(@output).to include("Exported to #{output_path}")
  end

  def then_the_error_output_includes(message)
    expect(@error).to include(message)
  end

  def and_the_exporter_is_not_called
    expect(Reports::AutomatedCareplusExporter).not_to have_received(:call)
  end
end
