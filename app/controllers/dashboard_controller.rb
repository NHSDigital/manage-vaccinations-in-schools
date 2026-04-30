# frozen_string_literal: true

class DashboardController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :set_primary_items, :set_secondary_items

  layout "full"

  def index
    @notices_count =
      (policy_scope(ImportantNotice).count if policy(ImportantNotice).index?)
  end

  private

  def set_primary_items
    @primary_items =
      if current_team.has_support_access?
        [
          {
            title: "Operational support tools",
            path: inspect_dashboard_path,
            description:
              "Inspect and troubleshoot individual records in the system.",
            width: "one-half"
          }
        ]
      elsif current_team.has_national_reporting_access?
        [
          {
            title: I18n.t("imports.index.title"),
            path: imports_path,
            description: I18n.t("imports.index.description_national_reporting"),
            width: "one-half"
          },
          {
            title: I18n.t("patients.index.title"),
            path: patients_path,
            description:
              I18n.t("patients.index.description_national_reporting"),
            width: "one-half"
          }
        ]
      else
        [
          {
            title: I18n.t("schools.index.title"),
            path: schools_path,
            description: I18n.t("schools.index.description"),
            width: "one-quarter"
          },
          {
            title: I18n.t("patients.index.title"),
            path: patients_path,
            description: I18n.t("patients.index.description"),
            width: "one-quarter"
          },
          {
            title: I18n.t("sessions.index.title"),
            path: sessions_path,
            description: I18n.t("sessions.index.description"),
            width: "one-quarter"
          },
          {
            title: I18n.t("vaccines.index.title"),
            path: vaccines_path,
            description: I18n.t("vaccines.index.description"),
            width: "one-quarter"
          }
        ]
      end
  end

  def set_secondary_items
    @secondary_items = []

    if current_team.has_point_of_care_access?
      @secondary_items << {
        title: I18n.t("school_moves.index.title"),
        path: school_moves_path,
        description: I18n.t("school_moves.index.description")
      }

      @secondary_items << {
        title: I18n.t("consent_forms.index.title"),
        path: consent_forms_path,
        description: I18n.t("consent_forms.index.description")
      }

      @secondary_items << {
        title: I18n.t("manage_data.index.title"),
        path: manage_data_path,
        description: I18n.t("manage_data.index.description")
      }

      @secondary_items << {
        title: I18n.t("reports.index.title"),
        path: reports_path,
        description: I18n.t("reports.index.description")
      }

      @secondary_items << {
        title: I18n.t("teams.show.title"),
        path: contact_details_team_path,
        description: I18n.t("teams.show.description")
      }
    end

    @secondary_items << {
      title: I18n.t("service.guide.title"),
      path: @service_guide_url,
      description: I18n.t("service.guide.description")
    }
  end
end
