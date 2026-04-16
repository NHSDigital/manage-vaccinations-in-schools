# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis reports export-automated-careplus" do
  around { |example| travel_to(Date.new(2026, 3, 16)) { example.run } }

  let(:output_path) { Rails.root.join("tmp/test_automated_export.csv").to_s }

  after { File.delete(output_path) if File.exist?(output_path) }

  context "when there are no matching records" do
    it "informs the user and does not create an export" do
      given_an_organisation_with_a_single_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--start_date=2025-09-01",
        "--end_date=2026-03-10",
        "--output=#{output_path}"
      )

      expect(@output).to include(
        "No records found. No CarePlus report was created."
      )
      and_no_careplus_export_is_created
      expect(File.exist?(output_path)).to be(false)
    end
  end

  context "when there are matching vaccination records" do
    it "exports the CSV, creates an export record, links records, and reports success" do
      given_an_organisation_with_a_single_team
      given_a_vaccination_record_for_the_team

      when_i_run_the_command_with_options(
        "--ods_code=#{@organisation.ods_code}",
        "--output=#{output_path}"
      )

      export = CareplusExport.last
      expect(export.vaccination_records).to include(@vaccination_record)
      expect(export.programme_types).to eq([@programme.type])
      and_the_output_file_is_written
      and_the_success_message_is_displayed
    end
  end

  context "when inserting vaccination record links fails" do
    it "rolls back the export record too" do
      given_an_organisation_with_a_single_team
      given_a_vaccination_record_for_the_team

      allow(CareplusExportVaccinationRecord).to receive(:insert_all!).and_raise(
        ActiveRecord::ActiveRecordError
      )

      expect {
        capture_output do
          command(
            "--ods_code=#{@organisation.ods_code}",
            "--output=#{output_path}"
          )
        end
      }.to raise_error(ActiveRecord::ActiveRecordError).and(
        not_change(CareplusExport, :count)
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
      given_a_vaccination_record_for_the_team

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
      programme = Programme.hpv
      session = create(:session, team: @team, programmes: [programme])
      create(
        :vaccination_record,
        session:,
        programme:,
        performed_at: Date.new(2024, 10, 1)
      )

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

  def given_a_vaccination_record_for_the_team
    @programme = Programme.hpv
    session = create(:session, team: @team, programmes: [@programme])
    @vaccination_record =
      create(:vaccination_record, session:, programme: @programme)
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
