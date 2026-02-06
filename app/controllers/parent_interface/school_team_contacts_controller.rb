# frozen_string_literal: true

module ParentInterface
  class SchoolTeamContactsController < ApplicationController
    include Pagy::Backend
    include WizardControllerConcern

    skip_before_action :authenticate_user!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    skip_before_action :set_navigation_items

    prepend_before_action :set_school_team_contact_form
    before_action :clear_school_for_new_search,
                  if: -> { current_step == :school && request.get? }
    before_action :require_school_for_contact_details,
                  if: -> { current_step == :contact_details }
    before_action :set_schools_for_search, if: -> { current_step == :school }

    def show
      set_school_and_team_locations if current_step == :contact_details

      render_wizard
    end

    def update
      case current_step
      when :school
        handle_school
      end

      reload_steps

      render_wizard @school_team_contact_form
    end

    private

    def set_school_team_contact_form
      @school_team_contact_form =
        SchoolTeamContactForm.new(request_session: session)
    end

    def clear_school_for_new_search
      stored = session["school_team_contact"] || {}
      session["school_team_contact"] = stored.except("school_id")
      @school_team_contact_form =
        SchoolTeamContactForm.new(request_session: session)
    end

    def set_steps
      self.steps = @school_team_contact_form.wizard_steps
    end

    def require_school_for_contact_details
      return if @school_team_contact_form.school_id.present?

      redirect_to wizard_path(:school)
    end

    def set_schools_for_search
      @query = params[:q]
      scope =
        Location
          .school
          .with_team(academic_year: AcademicYear.pending)
          .search_by_name(@query)
      @pagy, @schools = pagy(scope, limit: 10)
    end

    def set_school_and_team_locations
      @school = @school_team_contact_form.school
      raise ActiveRecord::RecordNotFound unless @school

      @team_locations = find_team_locations_for_school(@school)
    end

    def handle_school
      @school_team_contact_form.assign_attributes(update_params)
      @school_team_contact_form.wizard_step = current_step
      @school_team_contact_form.save(context: :update)
    end

    def update_params
      permitted_attributes = {
        school: [:school_id],
        contact_details: []
      }.fetch(current_step)

      permitted =
        params
          .fetch(:school_team_contact_form, {})
          .permit(permitted_attributes)
          .merge(wizard_step: current_step)

      if current_step == :school
        permitted[:school_id] = permitted[:school_id].presence
      end

      permitted
    end

    def find_team_locations_for_school(school)
      school
        .team_locations
        .includes(:team, :subteam)
        .where(academic_year: AcademicYear.pending)
        .order("teams.name")
    end

    def set_header_path
      @header_path = wizard_path(:school)
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
      @privacy_policy_url = nil
    end
  end
end
