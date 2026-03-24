# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis schools create" do
  context "with valid arguments" do
    it "runs successfully" do
      when_i_run_the_command
      then_the_school_is_created
    end
  end

  private

  def command
    Dry::CLI.new(MavisCLI).call(
      arguments: %w[schools create 123456 MySchool 123 456 primary --site A]
    )
  end

  def when_i_run_the_command
    @output = capture_output { command }
  end

  def then_the_school_is_created
    location = Location.gias_school.find_by(urn: "123456")
    expect(location).to be_open
    expect(location.name).to eq("MySchool")
    expect(location.name).to eq("MySchool")
    expect(location.gias_establishment_number).to eq(123)
    expect(location.gias_local_authority_code).to eq(456)
    expect(location.gias_phase).to eq("primary")
  end
end
