# frozen_string_literal: true

class AppConsentSummaryComponent < ViewComponent::Base
  def initialize(
    consent,
    change_links: {},
    show_email_address: false,
    show_notes: false,
    show_parent_name: false,
    show_notify_parent: false,
    show_phone_number: false,
    show_programme: false,
    show_route: false
  )
    @consent = consent
    @change_links = change_links
    @show_email_address = show_email_address
    @show_notes = show_notes
    @show_parent_name = show_parent_name
    @show_notify_parent = show_notify_parent
    @show_phone_number = show_phone_number
    @show_programme = show_programme
    @show_route = show_route
  end

  def call = govuk_summary_list(rows:, actions: @change_links.present?)

  private

  attr_reader :consent,
              :change_links,
              :show_parent_name,
              :show_phone_number,
              :show_email_address,
              :show_programme,
              :show_notify_parent,
              :show_notes,
              :show_route

  delegate :programme, to: :consent
  delegate :consent_response_tag,
           :govuk_summary_list,
           :consent_parent_name,
           :consent_parent_email,
           :consent_parent_phone,
           to: :helpers

  def rows
    [
      parent_name_row,
      phone_number_row,
      email_address_row,
      programme_row,
      date_row,
      route_row,
      response_row,
      chosen_vaccine_row,
      reason_for_refusal_row,
      notify_parents_on_vaccination_row,
      notify_parent_on_refusal_row,
      notes_row
    ].compact
  end

  def parent_name_row
    if show_parent_name && (name = consent_parent_name(consent)).present?
      { key: { text: "Parent" }, value: { text: name } }
    end
  end

  def phone_number_row
    if show_phone_number && (phone = consent_parent_phone(consent)).present?
      { key: { text: "Phone number" }, value: { text: phone } }
    end
  end

  def email_address_row
    if show_email_address && (email = consent_parent_email(consent)).present?
      { key: { text: "Email address" }, value: { text: email } }
    end
  end

  def programme_row
    return unless show_programme

    {
      key: {
        text: "Programme"
      },
      value: {
        text:
          tag.strong(
            programme.name,
            class: "nhsuk-tag app-tag--attached app-tag--transparent"
          )
      }
    }
  end

  def date_row
    return if consent.responded_at.nil?

    {
      key: {
        text: "Date"
      },
      value: {
        text: consent.responded_at.to_fs(:long)
      }
    }
  end

  def route_row
    return unless show_route

    {
      key: {
        text: "Method"
      },
      value: {
        text: consent.human_enum_name(:route).humanize
      },
      actions: [
        if (href = change_links[:route])
          { href:, visually_hidden_text: "method" }
        end
      ].compact
    }
  end

  def response_row
    {
      key: {
        text: "Response"
      },
      value: {
        text: consent_response_tag(consent)
      },
      actions: [
        if (href = change_links[:response])
          { href:, visually_hidden_text: "decision" }
        end
      ].compact
    }
  end

  def chosen_vaccine_row
    return unless consent.response_given?

    unless programme.has_multiple_vaccine_methods? ||
             programme.vaccine_may_contain_gelatine?
      return
    end

    value =
      if consent.vaccine_method_nasal_only?
        "Nasal spray only"
      elsif consent.without_gelatine
        gelatine_free_vaccine_text
      else
        no_preference_text
      end

    { key: { text: "Chosen vaccine" }, value: { text: value } }
  end

  def gelatine_free_vaccine_text
    if programme.flu?
      "Injected vaccine only"
    else
      "Gelatine-free injected vaccine only"
    end
  end

  def no_preference_text
    if programme.has_multiple_vaccine_methods?
      "Nasal spray or injected vaccine"
    elsif programme.vaccine_may_contain_gelatine?
      "Gelatine-free injected vaccine or injected vaccine"
    else
      "No preference"
    end
  end

  def reason_for_refusal_row
    return if consent.reason_for_refusal.nil?

    {
      key: {
        text: "Reason for refusal"
      },
      value: {
        text: helpers.refusal_reason_label(consent)
      }
    }
  end

  def notify_parents_on_vaccination_row
    return unless show_notify_parent
    return if consent.notify_parents_on_vaccination.nil?

    {
      key: {
        text: "Confirmation of vaccination sent to parent?"
      },
      value: {
        text: consent.notify_parents_on_vaccination ? "Yes" : "No"
      },
      actions: [
        if (href = change_links[:notify_parents_on_vaccination])
          {
            href:,
            visually_hidden_text: "confirmation of vaccination sent to parent"
          }
        end
      ].compact
    }
  end

  def notify_parent_on_refusal_row
    return unless show_notify_parent
    return if consent.notify_parent_on_refusal.nil?

    {
      key: {
        text: "Confirmation of decision sent to parent?"
      },
      value: {
        text: consent.notify_parent_on_refusal ? "Yes" : "No"
      }
    }
  end

  def notes_row
    return unless show_notes
    return if consent.notes.blank?

    { key: { text: "Notes" }, value: { text: consent.notes } }
  end
end
