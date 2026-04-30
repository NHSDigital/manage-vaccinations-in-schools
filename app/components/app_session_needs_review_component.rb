# frozen_string_literal: true

class AppSessionNeedsReviewComponent < ViewComponent::Base
  def initialize(
    session,
    include_missing_nhs_numbers: true,
    include_unmatched_responses: true
  )
    @session = session
    @include_missing_nhs_numbers = include_missing_nhs_numbers
    @include_unmatched_responses = include_unmatched_responses
  end

  def call
    render AppWarningCalloutComponent.new(heading: "Needs review", level: 2) do
      tag.ul { safe_join(list_items) }
    end
  end

  def render?
    show_missing_nhs_numbers? || show_unmatched_responses?
  end

  private

  attr_reader :session,
              :include_missing_nhs_numbers,
              :include_unmatched_responses

  delegate :patients, to: :session

  def list_items
    [missing_nhs_numbers_item, unmatched_responses_item].compact.map do |item|
      tag.li { link_to(item.fetch(:text), item.fetch(:href)) }
    end
  end

  def missing_nhs_numbers
    @missing_nhs_numbers ||= patients.without_nhs_number.count
  end

  def show_missing_nhs_numbers?
    include_missing_nhs_numbers && missing_nhs_numbers.positive?
  end

  def missing_nhs_numbers_item
    return unless show_missing_nhs_numbers?

    {
      text: t("children_without_nhs_number", count: missing_nhs_numbers),
      href: session_patients_path(session, missing_nhs_number: true)
    }
  end

  def unmatched_responses
    @unmatched_responses ||= ConsentForm.for_session(session).unmatched.count
  end

  def show_unmatched_responses?
    include_unmatched_responses && unmatched_responses.positive?
  end

  def unmatched_responses_item
    return unless show_unmatched_responses?

    {
      text: t("unmatched_responses", count: unmatched_responses),
      href: consent_forms_path(session_slug: session.slug)
    }
  end
end
