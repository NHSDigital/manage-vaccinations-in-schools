# frozen_string_literal: true

class AppManageDataNavigationComponent < ViewComponent::Base
  def initialize(active:, team:)
    @active = active
    @team = team
  end

  def call
    render AppSecondaryNavigationComponent.new do |nav|
      nav.with_item(
        href: imports_path,
        text: "Incomplete uploads",
        selected: active == :uploaded
      )

      nav.with_item(
        href: records_imports_path,
        text: "Completed imports",
        selected: active == :imported
      )

      if policy(%i[import issue]).index?
        nav.with_item(
          href: imports_issues_path,
          text: issues_text,
          selected: active == :issues
        )
      end

      if team.has_point_of_care_access?
        nav.with_item(
          href: downloads_path,
          text: "Downloads",
          selected: active == :exports
        )
      end

      if policy(ImportantNotice).index?
        nav.with_item(
          href: imports_notices_path,
          text: notices_text,
          selected: active == :notices
        )
      end
    end
  end

  private

  attr_reader :active, :team

  delegate :policy, :policy_scope, to: :helpers

  def issues_text
    count = TeamCachedCounts.new(team).import_issues
    text_with_count("Issues", count)
  end

  def notices_text
    count = policy_scope(ImportantNotice).count

    text_with_count("Important notices", count)
  end

  def text_with_count(text, count)
    safe_join([text, " ", render(AppCountComponent.new(count))])
  end
end
