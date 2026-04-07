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

  context "without --ods_code (fallback credentials)" do
    context "when the request succeeds" do
      it "prints the response body and a success message" do
        stub_careplus_request(status: 200, body: "<result>OK</result>")

        when_i_run_the_command("--input=#{input_path}")

        then_the_output_includes("Success (HTTP 200)")
        then_the_output_includes("<result>OK</result>")
      end

      it "sends the correct request with fallback credentials and namespace" do
        stub_careplus_request(status: 200, body: "")

        when_i_run_the_command("--input=#{input_path}")

        expect(WebMock).to have_requested(:post, default_endpoint).with(
          headers: {
            "Content-Type" => "text/xml; charset=utf-8"
          },
          body: /col1,col2/
        )
        expect(WebMock).to have_requested(:post, default_endpoint).with(
          body: /mavis_user/
        )
        expect(WebMock).to have_requested(:post, default_endpoint).with(
          body: %r{careplus\.syhapp\.thirdparty\.nhs\.uk/MOCK/webservices}
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
  end

  context "with --ods_code (team credentials)" do
    context "when the organisation does not exist" do
      it "warns and does not make a request" do
        when_i_run_the_command_and_capture_error(
          "--input=#{input_path}",
          "--ods_code=UNKNOWN"
        )

        then_the_error_output_includes(
          "Could not find organisation with ODS code 'UNKNOWN'"
        )
        and_no_request_was_made
      end
    end

    context "when the organisation has multiple teams and no workgroup is given" do
      it "warns and does not make a request" do
        given_an_organisation_with_multiple_teams

        when_i_run_the_command_and_capture_error(
          "--input=#{input_path}",
          "--ods_code=#{@organisation.ods_code}"
        )

        then_the_error_output_includes("has multiple teams")
        and_no_request_was_made
      end
    end

    context "when the team has no credentials configured" do
      it "warns and does not make a request" do
        given_an_organisation_with_a_team_without_credentials

        when_i_run_the_command_and_capture_error(
          "--input=#{input_path}",
          "--ods_code=#{@organisation.ods_code}"
        )

        then_the_error_output_includes(
          "does not have CarePlus credentials configured"
        )
        and_no_request_was_made
      end
    end

    context "when the team has credentials configured" do
      it "sends the correct request using the team's credentials and namespace, and prints a success message" do
        given_an_organisation_with_a_single_team
        stub_careplus_request(status: 200, body: "<result>OK</result>")

        when_i_run_the_command(
          "--input=#{input_path}",
          "--ods_code=#{@organisation.ods_code}"
        )

        expect(WebMock).to have_requested(:post, default_endpoint).with(
          body: /careplus_user/
        )
        expect(WebMock).to have_requested(:post, default_endpoint).with(
          body: %r{careplus\.syhapp\.thirdparty\.nhs\.uk/MOCK/webservices}
        )
        then_the_output_includes("Success (HTTP 200)")
      end
    end

    context "when a workgroup is specified" do
      it "sends the request using the matching team's credentials" do
        given_an_organisation_with_multiple_teams
        stub_careplus_request(status: 200, body: "")

        when_i_run_the_command(
          "--input=#{input_path}",
          "--ods_code=#{@organisation.ods_code}",
          "--workgroup=#{@team.workgroup}"
        )

        expect(WebMock).to have_requested(:post, default_endpoint).with(
          body: /careplus_user/
        )
      end
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

  def given_an_organisation_with_a_team_without_credentials
    @organisation = create(:organisation)
    create(
      :team,
      :with_careplus_enabled,
      organisation: @organisation,
      careplus_username: nil,
      careplus_password: nil,
      programmes: Programme.all
    )
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
