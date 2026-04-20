# frozen_string_literal: true

module AuthenticationConcern
  extend ActiveSupport::Concern

  included do
    private

    # only return true if the given URL is part of this domain (relative or absolute)
    # or part of the mavis reporting app, or localhost (to support local dev)
    def is_valid_redirect?(url)
      !url_from(url).nil? ||
        url.start_with?(
          Settings.reporting_api.client_app.root_url || "http://localhost"
        )
    end

    def authenticate_user!
      if !user_signed_in?
        if request.path != start_path && request.path != new_users_teams_path
          location = Addressable::URI.parse(request.fullpath)
          location.query_values =
            (location.query_values || {}).delete("timeout")
          store_location_for(:user, location.to_s)
        end

        if cis2_enabled? || request.path != new_user_session_path
          flash[:info] = (
            if session_timed_out?
              "You've been logged out for your security. Please log in again."
            else
              "You must be logged in to access this page."
            end
          )
          redirect_to start_path
        end
      elsif cis2_enabled?
        if !selected_cis2_role_is_valid?
          redirect_to users_role_not_found_path
        elsif !selected_cis2_org_is_registered?
          redirect_to users_organisation_not_found_path
        elsif !selected_cis2_workgroup_is_valid?
          redirect_to users_workgroup_not_found_path
        end
      end
    end

    def cis2_enabled? = Settings.cis2.enabled

    def cis2_info = CIS2Info.new(request_session: session)

    def selected_cis2_org_is_registered?
      Organisation.exists?(ods_code: cis2_info.organisation_code)
    end

    def selected_cis2_workgroup_is_valid?
      cis2_info.has_valid_workgroup?
    end

    def selected_cis2_role_is_valid?
      cis2_info.is_medical_secretary? || cis2_info.is_nurse? ||
        cis2_info.is_healthcare_assistant? || cis2_info.is_superuser? ||
        cis2_info.is_prescriber? || cis2_info.is_support?
    end

    def storable_location?
      request.get? && is_navigational_format? && !devise_controller? &&
        !request.xhr? && !turbo_frame_request?
    end

    def store_redirect_uri!
      if params.key?(:redirect_uri)
        session[:redirect_uri] = params.fetch(:redirect_uri)
      end
    end

    def store_user_location!
      return unless user_signed_in?
      return unless storable_location?

      store_location_for(:user, request.fullpath)
    end

    def add_auth_code_to(url, user)
      uri = Addressable::URI.parse(url)
      auth_code =
        ReportingAPI::OneTimeToken.find_or_generate_for!(
          user:,
          cis2_info: session["cis2_info"]
        ).token
      uri.query_values = (uri.query_values || {}).merge("code" => auth_code)
      uri.to_s
    end

    def reporting_app_redirect_uri_with_auth_code_for(user)
      return if cis2_info.team_workgroup.blank?

      url = session.delete("redirect_uri")
      return if url.blank?

      add_auth_code_to(url, user)
    end

    def authenticate_basic
      if Flipper.enabled?(:basic_auth)
        authenticated =
          authenticate_with_http_basic do |username, password|
            username == Rails.application.credentials.support_username &&
              password == Rails.application.credentials.support_password
          end

        unless authenticated
          request_http_basic_authentication "Application", <<~MESSAGE
          Access is currently restricted to authorised users only.
          MESSAGE
        end
      end
    end

    def after_sign_in_path_for(scope)
      urls = []

      urls << inspect_dashboard_path if cis2_info.is_support?

      urls << reporting_app_redirect_uri_with_auth_code_for(current_user)

      urls += [
        stored_location_for(scope),
        session[:user_return_to],
        dashboard_path
      ]

      urls.compact.find do
        is_valid_redirect?(it) && (it != request.fullpath) &&
          (it != new_users_teams_path)
      end
    end

    def redirect_after_choosing_org
      url = after_sign_in_path_for(current_user)
      redirect_to url, allow_other_host: is_valid_redirect?(url)
    end

    def user_signed_in?
      super && (cis2_enabled? ? cis2_info.present? : true)
    end

    def set_user_cis2_info
      current_user&.cis2_info = CIS2Info.new(request_session: session)
    end

    def selected_cis2_nrbac_role
      return {} if raw_cis2_info["selected_roleid"].blank?

      @selected_cis2_nrbac_role ||=
        raw_cis2_info["nhsid_nrbac_roles"].find do
          it["person_roleid"] == raw_cis2_info["selected_roleid"]
        end
    end

    def selected_cis2_org
      return {} if selected_cis2_nrbac_role.empty?

      @selected_cis2_org ||=
        raw_cis2_info["nhsid_user_orgs"].find do
          it["org_code"] == selected_cis2_nrbac_role["org_code"]
        end
    end

    def session_timed_out? = params.key?(:timeout)
  end
end
