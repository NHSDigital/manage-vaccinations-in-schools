# frozen_string_literal: true

module TriagesHelper
  def triage_status_text(triage)
    return if triage.nil?

    if triage.delay_vaccination? && triage.delay_vaccination_until.present?
      "Delay vaccination until #{triage.delay_vaccination_until.to_fs(:long)}"
    else
      status_method =
        if triage.programme.has_multiple_vaccine_methods? &&
             triage.vaccine_method.present?
          triage.status + "_#{triage.vaccine_method}"
        else
          triage.status
        end

      Triage.human_enum_name(:status, status_method)
    end
  end

  def triage_status_tag(triage)
    text = triage_status_text(triage)

    colour =
      if triage.invalidated?
        "grey"
      elsif triage.safe_to_vaccinate?
        "green"
      elsif triage.do_not_vaccinate?
        "red"
      elsif triage.delay_vaccination? || triage.invite_to_clinic?
        "orange"
      else
        "blue"
      end

    if triage.invalidated?
      safe_join(
        [
          govuk_tag(text: tag.s(text), colour:),
          tag.span("Invalid", class: "nhsuk-u-secondary-text-colour")
        ]
      )
    else
      govuk_tag(text:, colour:)
    end
  end

  def triage_summary(triage)
    prefix =
      if (performed_by = triage.performed_by)
        "#{performed_by.full_name} decided that "
      else
        ""
      end

    suffix =
      if triage.safe_to_vaccinate?
        if triage.vaccine_method.present? &&
             triage.programme.has_multiple_vaccine_methods?
          vaccination_method =
            Vaccine.human_enum_name(:method_prefix, triage.vaccine_method)
          " is safe to vaccinate using the #{vaccination_method} vaccine only."
        else
          " is safe to vaccinate."
        end
      elsif triage.do_not_vaccinate?
        " should not be vaccinated."
      elsif triage.delay_vaccination?
        if triage.delay_vaccination_until.present?
          "’s vaccination should be delayed until #{triage.delay_vaccination_until.to_fs(:long)}."
        else
          "’s vaccination should be delayed."
        end
      elsif triage.invite_to_clinic?
        "’s vaccination should take place at a clinic."
      end

    "#{prefix}#{triage.patient.given_name}#{suffix}" if suffix
  end
end
