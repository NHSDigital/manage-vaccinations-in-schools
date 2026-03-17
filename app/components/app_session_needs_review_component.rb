# frozen_string_literal: true

class AppSessionNeedsReviewComponent < ViewComponent::Base
  def initialize(session)
    @session = session
  end

  def call
    render AppWarningCalloutComponent.new(heading: "Needs review", level: 2) do
      tag.ul do
        safe_join(
          items.map do |item|
            tag.li { link_to(item[:text].call, item[:href].call) }
          end
        )
      end
    end
  end

  def render? = items.present?

  private

  attr_reader :session

  delegate :patients, to: :session

  def items
    @items ||= [children_without_nhs_number, unmatched_responses].compact
  end

  def children_without_nhs_number
    count = patients.without_nhs_number.count
    return if count.zero?

    {
      text: -> { t("children_without_nhs_number", count:) },
      href: -> { session_patients_path(session, missing_nhs_number: true) }
    }
  end

  def unmatched_responses
    count = ConsentForm.for_session(session).unmatched.count
    return if count.zero?

    {
      text: -> { t("unmatched_responses", count:) },
      href: -> { consent_forms_path(session_slug: @session.slug) }
    }
  end
end
