# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis pds search", :pds do
  it "runs successfully" do
    given_the_request_is_stubbed

    when_i_run_the_command
    then_the_patient_details_are_output
  end

  def command
    Dry::CLI.new(MavisCLI).call(arguments: %w[pds search --given-name ELDREDA])
  end

  def given_the_request_is_stubbed
    stub_pds_search_to_return_a_patient(
      "_exact-match" => "false",
      "_fuzzy-match" => "false",
      "_history" => "false",
      "_max-results" => "10",
      "given" => "ELDREDA"
    )
  end

  def when_i_run_the_command
    @output = capture_output { command }
  end

  def then_the_patient_details_are_output
    expect(@output).to include("Patient")
    expect(@output).to include("ELDREDA")
    expect(@output).to include("LAWMAN")
  end
end
