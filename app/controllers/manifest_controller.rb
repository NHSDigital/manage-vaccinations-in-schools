# frozen_string_literal: true

class ManifestController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :store_user_location!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  skip_after_action :set_navigation_items_cookie
  skip_after_action :set_reporting_app_context_cookie

  before_action :set_assets_name

  def show
    render_block = -> do
      respond_to do |format|
        format.json do
          render "manifest/show", content_type: "application/manifest+json"
        end
      end
    end

    if params[:digest] == helpers.manifest_digest
      http_cache_forever(public: true, &render_block)
    else
      expires_in 1.hour, public: true
      render_block
    end
  end

  private

  def set_assets_name
    @assets_name = params[:name] || "application"
  end
end
