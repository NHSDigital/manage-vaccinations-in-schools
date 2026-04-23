# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis pds get", :pds do
  it "runs successfully" do
    given_the_request_is_stubbed

    when_i_run_the_command
    then_the_patient_details_are_output
  end

  def command
    Dry::CLI.new(MavisCLI).call(arguments: %w[pds get 1234567890])
  end

  def given_the_request_is_stubbed
    stub_pds_get_nhs_number_to_return_a_patient("1234567890")
  end

  def when_i_run_the_command
    @output = capture_output { command }
  end

  def then_the_patient_details_are_output
    expect(@output).to include("Patient")
    expect(@output).to include("Jane")
    expect(@output).to include("Smith")
  end
end
