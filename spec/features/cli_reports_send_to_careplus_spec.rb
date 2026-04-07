# frozen_string_literal: true

require_relative "../../app/lib/mavis_cli"

describe "mavis reports send-to-careplus" do
  let(:csv_content) { "col1,col2\nval1,val2\n" }
  let(:input_path) { Rails.root.join("tmp/test_careplus_input.csv").to_s }

  before { File.write(input_path, csv_content) }
  after { FileUtils.rm_f(input_path) }

  context "when the input file does not exist" do
    it "warns and does not make a request" do
      stub_careplus_request

      when_i_run_the_command_and_capture_error("--input=/nonexistent/file.csv")

      then_the_error_output_includes("File not found: '/nonexistent/file.csv'")
      and_no_request_was_made
    end
  end

  context "when the request succeeds" do
    it "prints the response body and a success message" do
      stub_careplus_request(status: 200, body: "<result>OK</result>")

      when_i_run_the_command("--input=#{input_path}")

      then_the_output_includes("Success (HTTP 200)")
      then_the_output_includes("<result>OK</result>")
    end

    it "sends the CSV payload in the request" do
      stub_careplus_request(status: 200, body: "")

      when_i_run_the_command("--input=#{input_path}")

      expect(WebMock).to have_requested(:post, default_endpoint).with(
        body: /col1,col2/
      )
    end

    it "sends a text/xml content-type header" do
      stub_careplus_request(status: 200, body: "")

      when_i_run_the_command("--input=#{input_path}")

      expect(WebMock).to have_requested(:post, default_endpoint).with(
        headers: {
          "Content-Type" => "text/xml; charset=utf-8"
        }
      )
    end
  end

  context "when the request fails" do
    it "warns with the status and response body" do
      stub_careplus_request(status: 400, body: "<fault>Bad request</fault>")

      when_i_run_the_command_and_capture_error("--input=#{input_path}")

      then_the_error_output_includes("Request failed with HTTP 400")
      then_the_error_output_includes("<fault>Bad request</fault>")
    end
  end

  context "when a custom endpoint is specified" do
    it "sends the request to the custom endpoint" do
      custom_endpoint = "http://custom-host:9090/soap"
      stub_careplus_request(endpoint: custom_endpoint, status: 200, body: "")

      when_i_run_the_command(
        "--input=#{input_path}",
        "--endpoint=#{custom_endpoint}"
      )

      expect(WebMock).to have_requested(:post, custom_endpoint)
    end
  end

  context "when the CSV payload contains XML special characters" do
    it "escapes them before embedding in the envelope" do
      File.write(input_path, "name\n<Test> & \"School\"\n")
      stub_careplus_request(status: 200, body: "")

      when_i_run_the_command("--input=#{input_path}")

      expect(WebMock).to have_requested(:post, default_endpoint).with(
        body: /&lt;Test&gt; &amp; &quot;School&quot;/
      )
    end
  end

  private

  def default_endpoint
    MavisCLI::Reports::SendToCareplus::DEFAULT_ENDPOINT
  end

  def stub_careplus_request(endpoint: default_endpoint, status: 200, body: "")
    stub_request(:post, endpoint).to_return(
      status:,
      body:,
      headers: {
        "Content-Type" => "text/xml"
      }
    )
  end

  def command(*args)
    Dry::CLI.new(MavisCLI).call(
      arguments: ["reports", "send-to-careplus", *args]
    )
  end

  def when_i_run_the_command(*args)
    @output = capture_output { command(*args) }
  end

  def when_i_run_the_command_and_capture_error(*args)
    @error = capture_error { command(*args) }
  end

  def then_the_output_includes(message)
    expect(@output).to include(message)
  end

  def then_the_error_output_includes(message)
    expect(@error).to include(message)
  end

  def and_no_request_was_made
    expect(WebMock).not_to have_requested(:post, default_endpoint)
  end
end
