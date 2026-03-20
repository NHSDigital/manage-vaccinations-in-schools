# frozen_string_literal: true

module ParentInterface
  class ConsentForms::BaseController < ApplicationController
    skip_before_action :authenticate_user!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    skip_before_action :set_navigation_items

    prepend_before_action :set_programmes
    prepend_before_action :set_team
    prepend_before_action :set_team_location
    prepend_before_action :set_session
    prepend_before_action :set_consent_form

    before_action :authenticate_consent_form_user!
    before_action :check_if_past_deadline!
    before_action :set_privacy_policy_url

    private

    def set_consent_form
      @consent_form =
        ConsentForm.includes(:consent_form_programmes).find(
          params[:consent_form_id] || params[:id]
        )
    end

    def set_session
      @session =
        if @consent_form
          @consent_form.session
        elsif params[:session_slug].present?
          Session.find_by!(slug: params[:session_slug])
        end
    end

    def set_team_location
      @team_location = @consent_form&.team_location || @session&.team_location
    end

    def set_team
      @team = @team_location.team
    end

    def set_programmes
      @programmes =
        if @consent_form
          @consent_form.consent_form_programmes.map(&:programme)
        elsif @session && params[:programme_types].present?
          types = params[:programme_types].split("-")

          @session.programmes.flat_map do
            it.variants.select { it.to_param.in?(types) }
          end
        end

      raise ActiveRecord::RecordNotFound if @programmes.empty?
    end

    def set_header_path
      @header_path =
        start_parent_interface_consent_forms_path(
          @session,
          @programmes.map(&:to_param).join("-")
        )
    end

    def set_assets_name
      @assets_name = "public"
    end

    def set_service_name
      @service_name = "Give or refuse consent for vaccinations"
    end

    def set_service_url
      @service_url =
        "https://www.give-or-refuse-consent-for-vaccinations.nhs.uk"
    end

    def set_secondary_navigation
      @show_secondary_navigation = false
    end

    def set_service_guide_url
      @service_guide_url = nil
    end

    def set_privacy_policy_url
      @privacy_policy_url = @team.privacy_policy_url
    end

    def authenticate_consent_form_user!
      unless session[:consent_form_id] == @consent_form.id
        redirect_to @header_path
      end
    end

    def check_if_past_deadline!
      return if @session.unscheduled?
      return if @session.can_receive_consent?

      redirect_to deadline_passed_parent_interface_consent_forms_path(
                    @session.slug,
                    @programmes.map(&:type).join("-")
                  )
    end
  end
end
