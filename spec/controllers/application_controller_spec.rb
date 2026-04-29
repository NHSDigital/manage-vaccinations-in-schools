# frozen_string_literal: true

describe ApplicationController do
  controller do
    skip_before_action :authenticate_user!
    skip_before_action :store_user_location!
    skip_before_action :ensure_team_is_selected
    skip_before_action :set_user_cis2_info
    skip_before_action :set_disable_cache_headers
    skip_before_action :set_header_path
    skip_before_action :set_assets_name
    skip_before_action :set_theme_colour
    skip_before_action :set_service_name
    skip_before_action :set_service_url
    skip_before_action :set_service_guide_url
    skip_before_action :set_privacy_policy_url
    skip_before_action :set_sentry_user
    skip_before_action :authenticate_basic
    skip_before_action :set_cached_counts
    skip_before_action :set_navigation_items
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      head :ok
    end
  end

  before { routes.draw { get "index" => "anonymous#index" } }

  describe "after_action :set_reporting_app_context_cookie" do
    let(:team) { create(:team) }
    let(:user) { create(:user, team:) }
    let(:cis2_info) { double(team:) }
    let(:navigation_items) { [] }
    let(:reporting_app_context_cookie) do
      JSON.parse(cookies[:mavis_reporting_context])
    end

    before do
      allow(user).to receive(:cis2_info).and_return(cis2_info)
      allow(controller).to receive_messages(
        current_user: user,
        reporting_app_navigation_items: navigation_items
      )
    end

    context "when the current team has CarePlus credentials" do
      let(:team) { create(:team, :with_careplus_enabled) }

      it "sets the reporting app context cookie" do
        get :index

        expect(reporting_app_context_cookie).to eq(
          { "navigation_items" => [], "careplus_reports_tab_visible" => true }
        )
      end
    end

    context "when the current team does not have CarePlus credentials" do
      let(:team) { create(:team) }

      it "sets the CarePlus flag to false" do
        get :index

        expect(
          reporting_app_context_cookie["careplus_reports_tab_visible"]
        ).to be(false)
      end
    end

    context "when the current team has only some CarePlus credentials" do
      let(:team) { create(:team, careplus_namespace: "MOCK") }

      it "sets the CarePlus flag to false" do
        get :index

        expect(
          reporting_app_context_cookie["careplus_reports_tab_visible"]
        ).to be(false)
      end
    end

    context "when the current user does not yet have cis2 info" do
      let(:cis2_info) { nil }

      it "sets the reporting app context cookie with the CarePlus flag false" do
        get :index

        expect(reporting_app_context_cookie).to eq(
          { "navigation_items" => [], "careplus_reports_tab_visible" => false }
        )
      end
    end

    context "when there is no current user" do
      it "does not set the cookie" do
        allow(controller).to receive(:current_user).and_return(nil)

        get :index

        expect(cookies[:mavis_reporting_context]).to be_nil
      end
    end

    context "when navigation items are available" do
      let(:navigation_items) { [{ title: "Reports", path: "/reports" }] }

      it "includes navigation items in the reporting app context cookie" do
        get :index

        expect(reporting_app_context_cookie["navigation_items"]).to eq(
          [{ "title" => "Reports", "path" => "/reports" }]
        )
      end
    end
  end
end
