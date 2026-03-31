# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis reports export-automated-careplus" do
  around { |example| travel_to(Date.new(2026, 3, 16)) { example.run } }

  let(:output_path) { Rails.root.join("tmp/test_automated_export.csv").to_s }

  after { File.delete(output_path) if File.exist?(output_path) }

  context "with a valid organisation and single team" do
    it "exports the CSV, creates an export record, and reports success" do
      given_an_organisation_with_a_single_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--start_date=2025-09-01",
        "--end_date=2026-03-10",
        "--output=#{output_path}"
      )

      then_a_careplus_export_is_created_with(
        team: @team,
        academic_year: AcademicYear.current,
        date_from: Date.new(2025, 9, 1),
        date_to: Date.new(2026, 3, 10),
        status: "sent",
        csv_filename: File.basename(output_path)
      )
      and_the_output_file_is_written
      and_the_success_message_is_displayed
    end
  end

  context "when there are matching vaccination records" do
    it "links them to the export" do
      given_an_organisation_with_a_single_team
      programme = Programme.hpv
      session = create(:session, team: @team, programmes: [programme])
      vaccination_record = create(:vaccination_record, session:, programme:)

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--output=#{output_path}"
      )

      expect(CareplusExport.last.vaccination_records).to include(
        vaccination_record
      )
    end
  end

  context "when the organisation does not exist" do
    it "warns and does not create an export" do
      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=UNKNOWN"
      )
      then_the_error_output_includes(
        "Could not find organisation with ODS code 'UNKNOWN'"
      )
      and_no_careplus_export_is_created
    end
  end

  context "when the organisation has multiple teams and no workgroup is given" do
    it "warns and does not create an export" do
      given_an_organisation_with_multiple_teams

      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=#{@organisation.ods_code}"
      )
      then_the_error_output_includes("has multiple teams")
      and_no_careplus_export_is_created
    end
  end

  context "when a workgroup is specified" do
    it "creates the export for the matching team" do
      given_an_organisation_with_multiple_teams

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--workgroup=#{@team.workgroup}",
        "--output=#{output_path}"
      )
      then_a_careplus_export_is_created_with(team: @team)
    end
  end

  context "when a custom academic year is specified" do
    it "creates the export with the given academic year" do
      given_an_organisation_with_a_single_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--academic_year=2024",
        "--output=#{output_path}"
      )
      then_a_careplus_export_is_created_with(academic_year: 2024)
    end
  end

  context "when the team does not have CarePlus enabled" do
    it "warns and does not create an export" do
      given_an_organisation_with_a_team_without_careplus

      when_i_run_the_command_with_options_and_capture_error(
        "--ods_code=#{@organisation.ods_code}"
      )
      then_the_error_output_includes("does not have CarePlus enabled")
      and_no_careplus_export_is_created
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

  def then_a_careplus_export_is_created_with(**kwargs)
    expect(CareplusExport.last).to have_attributes(**kwargs)
  end

  def and_the_output_file_is_written
    expect(File.exist?(output_path)).to be(true)
  end

  def and_the_success_message_is_displayed
    expect(@output).to include("Exported to #{output_path}")
  end

  def then_the_error_output_includes(message)
    expect(@error).to include(message)
  end

  def and_no_careplus_export_is_created
    expect(CareplusExport.count).to eq(0)
  end
end
