# frozen_string_literal: true

describe AuthenticationConcern do
  let(:user) { @user = build(:user) }
  let(:mock_request) { instance_double(request.class, headers: {}) }
  let(:sample_class) do
    Class
      .new do # rubocop:disable Style/BlockDelimiters
        include AuthenticationConcern

        attr_accessor :request, :session

        def initialize(request: nil, session: {})
          @request = request
          @session = session
        end

        def params
          {}
        end

        def render(content = {}, args = {})
        end

        def current_user
          @user
        end
      end # rubocop:disable Style/MethodCalledOnDoEndBlock
      .new(request: mock_request)
  end

  describe "#set_user_cis2_info" do
    let(:user) { build(:user, cis2_info: nil) }

    context "when cis2 is disabled" do
      it "does not set the user's cis2_info" do
        allow(Settings).to receive(:cis2).and_return(double(enabled: false))

        sample_class.send(:set_user_cis2_info)

        expect(user.cis2_info).to be_nil
      end
    end

    context "when cis2 is enabled" do
      it "does not set the user's cis2_info" do
        allow(Settings).to receive(:cis2).and_return(double(enabled: true))

        sample_class.send(:set_user_cis2_info)

        expect(user.cis2_info).to be_nil
      end
    end
  end

  describe "#add_auth_code_to" do
    let(:user) { create(:user) }
    let(:token) do
      build(:reporting_api_one_time_token, user: user, token: "mytoken")
    end
    let(:url) { "/some/relative/path.json" }
    let(:session_cis2_info) { { "some_key" => "some value" } }

    before do
      sample_class.session = { "cis2_info" => session_cis2_info }
      allow(ReportingAPI::OneTimeToken).to receive(:find_or_generate_for!).with(
        user: user,
        cis2_info: session_cis2_info
      ).and_return(token)
    end

    it "finds or generates a OneTimeToken for the given user with the cis2_info from the current session" do
      expect(ReportingAPI::OneTimeToken).to receive(
        :find_or_generate_for!
      ).with(user: user, cis2_info: session_cis2_info)
      sample_class.send(:add_auth_code_to, url, user)
    end

    context "given a url with no params" do
      let(:url) { "/some/relative/path.json" }

      it "adds the code param as a query string" do
        expect(sample_class.send(:add_auth_code_to, url, user)).to eq(
          "/some/relative/path.json?code=mytoken"
        )
      end
    end

    context "given a url with some params already" do
      let(:url) { "/some/relative/path.json?q=some%20search" }

      it "adds the code param as a query string" do
        expect(sample_class.send(:add_auth_code_to, url, user)).to eq(
          "/some/relative/path.json?code=mytoken&q=some%20search"
        )
      end
    end
  end

  describe "#reporting_app_redirect_uri_with_auth_code_for" do
    let(:session_cis2_info) { { "team_workgroup" => "r1l" } }
    let(:token) do
      build(:reporting_api_one_time_token, user: user, token: "mytoken")
    end
    let(:result) do
      sample_class.send(:reporting_app_redirect_uri_with_auth_code_for, user)
    end

    context "when there is a redirect_uri key in session" do
      before do
        allow(ReportingAPI::OneTimeToken).to receive(
          :find_or_generate_for!
        ).with(user: user, cis2_info: session_cis2_info).and_return(token)
        sample_class.session = {
          "redirect_uri" =>
            "http://reporting.mavis:5555/path?some_param=some%20value",
          "cis2_info" => session_cis2_info
        }
      end

      it "returns that URL with a code added to it for the given user" do
        expect(result).to eq(
          "http://reporting.mavis:5555/path?code=mytoken&some_param=some%20value"
        )
      end

      it "deletes the redirect_uri from the session" do
        result
        expect(sample_class.session["redirect_uri"]).to be_nil
      end
    end

    context "when there is no redirect_uri key in session" do
      before { sample_class.session = { "cis2_info" => session_cis2_info } }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when the user has not selected a team" do
      let(:session_cis2_info) { {} }

      before do
        sample_class.session = {
          "redirect_uri" => "http://reporting.mavis:5555/path",
          "cis2_info" => session_cis2_info
        }
      end

      it "returns nil" do
        expect(result).to be_nil
      end

      it "preserves the redirect_uri in the session for later use" do
        result
        expect(sample_class.session["redirect_uri"]).to eq(
          "http://reporting.mavis:5555/path"
        )
      end
    end
  end
end
