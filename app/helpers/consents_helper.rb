# frozen_string_literal: true

module ConsentsHelper
  ConsentRefusalOption = Struct.new(:value, :label, :divider)

  def consent_refusal_reasons(consent)
    reasons = %w[
      already_vaccinated
      will_be_vaccinated_elsewhere
      medical_reasons
      personal_choice
      other
    ]

    if consent.vaccine_may_contain_gelatine?
      reasons.insert(0, "contains_gelatine")
    end

    reasons.map do |value|
      label = refusal_reason_label(consent, value)

      ConsentRefusalOption.new(value:, label:, divider: value == "other")
    end
  end

  def refusal_reason_label(consent, reason_value = nil)
    value = reason_value || consent&.reason_for_refusal
    return if value.blank?

    programme =
      if consent.respond_to?(:programme)
        consent.programme
      elsif consent.respond_to?(:programmes)
        consent.programmes.first
      end

    label_key =
      if value == "contains_gelatine"
        if programme&.flu?
          "contains_gelatine_flu"
        elsif programme&.mmr? && (variant_type = programme.variant_type)
          "contains_gelatine_#{variant_type}"
        else
          value
        end
      else
        value
      end

    Consent.human_enum_name(:reason_for_refusal, label_key)
  end

  def consent_response_tag(consent)
    text =
      if consent.withdrawn?
        Consent.human_enum_name(:response, :given)
      elsif consent.try(:refusal_with_follow_up?)
        Consent.human_enum_name(:response, :follow_up_requested)
      else
        consent.human_enum_name(:response)
      end

    colour =
      if consent.withdrawn? || consent.invalidated?
        "grey"
      elsif consent.response_given?
        "green"
      elsif consent.try(:refusal_with_follow_up?)
        "orange"
      elsif consent.response_refused?
        "red"
      else
        "blue"
      end

    if consent.invalidated? || consent.withdrawn?
      primary_tag = govuk_tag(text: tag.s(text), colour:)

      secondary_text =
        tag.span(class: "nhsuk-u-secondary-text-colour") do
          safe_join(
            [
              if consent.invalidated?
                tag.span("Invalid")
              else
                tag.span("Withdrawn")
              end
            ].compact,
            " "
          )
        end

      safe_join([primary_tag, secondary_text])
    else
      govuk_tag(text:, colour:)
    end
  end

  def consent_action_links(consent, session:)
    patient = consent.patient
    programme = consent.programme

    follow_up_link =
      if consent.can_follow_up?
        {
          text: "Follow up",
          href:
            follow_up_session_patient_programme_consent_path(
              session,
              patient,
              programme,
              consent
            )
        }
      end
    withdraw_link =
      if consent.can_withdraw?
        {
          text: "Withdraw consent",
          href:
            withdraw_session_patient_programme_consent_path(
              session,
              patient,
              programme,
              consent
            )
        }
      end
    invalidate_link =
      if consent.can_invalidate?
        {
          text: "Mark as invalid",
          href:
            invalidate_session_patient_programme_consent_path(
              session,
              patient,
              programme,
              consent
            )
        }
      end

    [follow_up_link, withdraw_link, invalidate_link].compact
  end

  def consent_parent_name(consentable)
    consentable.parent_full_name.presence ||
      (consentable.respond_to?(:parent) ? consentable.parent&.full_name : nil)
  end

  def consent_parent_email(consentable)
    consentable.parent_email.presence ||
      (consentable.respond_to?(:parent) ? consentable.parent&.email : nil)
  end

  def consent_parent_phone(consentable)
    consentable.parent_phone.presence ||
      (consentable.respond_to?(:parent) ? consentable.parent&.phone : nil)
  end

  def consent_parent_phone_receive_updates(consentable)
    value = consentable.parent_phone_receive_updates
    if value.nil? && consentable.respond_to?(:parent)
      consentable.parent&.phone_receive_updates
    else
      value
    end
  end
end
