# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis gias import" do
  it "imports schools from a GIAS file" do
    given_a_gias_file_exists
    and_a_location_already_exists
    and_sites_exist

    when_i_run_the_import_command
    then_schools_are_imported_correctly
    and_sites_are_updated_too
  end

  it "displays a helpful message if the import file doesn't exist" do
    when_i_run_the_import_command_with_a_non_existent_file
    then_i_should_see_a_helpful_error_message
  end

  def given_a_gias_file_exists
    # Nothing to do here, it's a part of the fixtures
  end

  def and_a_location_already_exists
    create(:gias_school, :secondary, urn: "100000", site: nil)
  end

  def and_sites_exist
    create(
      :gias_school,
      urn: "100000",
      site: "A",
      name: "The Aldgate School - Site 2"
    )
    create(
      :gias_school,
      urn: "100000",
      site: "B",
      name: "The Aldgate School - Site 3"
    )
  end

  def when_i_run_the_import_command
    capture_output do
      Dry::CLI.new(MavisCLI).call(
        arguments: %w[gias import -i spec/fixtures/files/dfe-schools.zip]
      )
    end
  end

  def when_i_run_the_import_command_with_a_non_existent_file
    @msg, @exit_status =
      capture_error do
        Dry::CLI.new(MavisCLI).call(
          arguments: %w[gias import -i /non/existent/file]
        )
      end
  end

  def then_i_should_see_a_helpful_error_message
    expect(@msg.chomp).to eq(
      "Input file (/non/existent/file) not found. Run `bin/mavis gias download` first."
    )
  end

  def and_the_exit_status_should_indicate_that_it_was_unsuccessful
    expect(@exit_status.status).to eq(1)
  end

  def then_schools_are_imported_correctly
    expect(Location.count).to eq(7)
    expect(Location.find_by_urn_and_site("100000").name).to eq(
      "The Aldgate School"
    )
    expect(Location.find_by_urn_and_site!("100000").gias_phase).to eq("primary")

    expect(Location.find_by_urn_and_site("100000")).to be_closed
    expect(Location.find_by_urn_and_site("100001")).to be_closed
    expect(Location.find_by_urn_and_site("100002")).to be_closing
    expect(Location.find_by_urn_and_site("100003")).to be_open
  end

  def and_sites_are_updated_too
    expect(Location.find_by_urn_and_site("100000A").name).to eq(
      "The Aldgate School - Site 2"
    )
    expect(Location.find_by_urn_and_site("100000B").name).to eq(
      "The Aldgate School - Site 3"
    )
    expect(Location.find_by_urn_and_site("100000A")).to be_closed
    expect(Location.find_by_urn_and_site("100000B")).to be_closed
    expect(Location.find_by_urn_and_site("100000A").gias_phase).to eq("primary")
    expect(Location.find_by_urn_and_site("100000B").gias_phase).to eq("primary")
  end
end
