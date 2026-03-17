# frozen_string_literal: true

class AppLocationCardComponent < ViewComponent::Base
  def initialize(location, patient_count:, next_session_date:, heading_level: 4)
    @location = location
    @patient_count = patient_count
    @next_session_date = next_session_date
    @heading_level = heading_level
  end

  def call
    render AppCardComponent.new(link_to:, compact: true) do |card|
      card.with_heading(level: @heading_level) { heading }
      govuk_summary_list(rows:)
    end
  end

  private

  attr_reader :location, :patient_count, :next_session_date

  delegate :govuk_summary_list, to: :helpers

  def link_to
    school_patients_path(
      location.generic_clinic? ? Location::URN_UNKNOWN : location
    )
  end

  def heading = location.school_name

  def rows
    [
      patient_count_row,
      urn_row,
      phase_row,
      address_row,
      next_session_date_row
    ].compact
  end

  def patient_count_row
    {
      key: {
        text: "Children"
      },
      value: {
        text: I18n.t("children", count: patient_count)
      }
    }
  end

  def urn_row
    return if location.urn_and_site.blank?

    {
      key: {
        text: "URN"
      },
      value: {
        text: tag.span(location.urn_and_site, class: "app-u-code")
      }
    }
  end

  def phase_row
    return if location.phase.blank?

    {
      key: {
        text: "Phase"
      },
      value: {
        text: location.human_enum_name(:phase)
      }
    }
  end

  def address_row
    return unless location.has_address?

    {
      key: {
        text: "Address"
      },
      value: {
        text: helpers.format_address_multi_line(location)
      }
    }
  end

  def next_session_date_row
    return if next_session_date.nil?

    {
      key: {
        text: "Next session"
      },
      value: {
        text: next_session_date.to_fs(:long)
      }
    }
  end
end
