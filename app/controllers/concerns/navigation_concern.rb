# frozen_string_literal: true

module NavigationConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_cached_counts
    before_action :set_navigation_items
    after_action :set_navigation_items_cookie
  end

  def set_cached_counts
    @cached_counts = TeamCachedCounts.new(current_team)
  end

  def set_navigation_items
    @navigation_items = []

    if current_team&.has_point_of_care_access?
      @navigation_items << {
        title: t("schools.index.title"),
        path: schools_path
      }

      @navigation_items << {
        title: t("patients.index.title"),
        path: patients_path
      }

      @navigation_items << {
        title: t("sessions.index.title"),
        path: sessions_path
      }

      @navigation_items << {
        title: t("vaccines.index.title"),
        path: vaccines_path
      }

      @navigation_items << {
        title: t("consent_forms.index.title_short"),
        path: consent_forms_path,
        count: @cached_counts.unmatched_consent_responses
      }

      @navigation_items << {
        title: t("school_moves.index.title"),
        path: school_moves_path,
        count: @cached_counts.school_moves
      }

      @navigation_items << {
        title: t("reports.index.title"),
        path: reports_path
      }

      @navigation_items << {
        title: t("imports.index.title_short"),
        path: imports_path,
        count: (@cached_counts.import_issues if policy(%i[import issue]).index?)
      }
    end

    if current_team&.has_national_reporting_access?
      @navigation_items << {
        title: t("imports.index.title_short"),
        path: imports_path,
        count: (@cached_counts.import_issues if policy(%i[import issue]).index?)
      }
    end

    if current_team&.has_point_of_care_access?
      @navigation_items << {
        title: I18n.t("teams.show.title_short"),
        path: contact_details_team_path
      }
    end

    if current_team&.has_national_reporting_access?
      @navigation_items << {
        title: t("patients.index.title"),
        path: patients_path
      }
    end

    if current_team&.has_support_access?
      @navigation_items << { title: "Tools", path: inspect_dashboard_path }
    end
  end

  # TODO: remove this cookie once the reporting app is using the new mavis_reporting_context cookie
  def set_navigation_items_cookie
    return unless current_user

    cookies[:mavis_navigation_items] = @navigation_items.to_json
  end
end
