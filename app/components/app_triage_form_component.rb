# frozen_string_literal: true

class AppTriageFormComponent < ViewComponent::Base
  def initialize(form, url:, method: :post, heading: true, continue: false)
    @form = form
    @url = url
    @method = method
    @heading = heading
    @continue = continue
  end

  private

  attr_reader :form, :url, :method, :heading, :continue

  delegate :policy, to: :helpers
  delegate :patient, :session, :programme, to: :form

  def builder = MavisFormBuilder

  def hint_text
    if programme.mmr? && patient_on_last_dose?
      "2nd dose is not due until #{form.next_mmr_dose_date.to_fs(:long)}"
    else
      "For example, #{hint_date.to_fs(:long)} "
    end
  end

  def hint_date
    Time.zone.today + 28.days
  end

  def fieldset_options
    text = "Is it safe to vaccinate #{patient.given_name}?"

    hint =
      if programme.has_multiple_vaccine_methods?
        if form.consented_to_injection_only?
          "The parent has consented to the injected vaccine only"
        elsif form.consented_to_injection?
          "The parent has consented to the injected vaccine being offered if the nasal spray is not suitable"
        else
          "The parent has consented to the nasal spray only"
        end
      end

    legend = { text:, size: "m", classes: "nhsuk-u-font-size-22" }

    if heading
      { legend: legend.merge(tag: :h2), hint: { text: hint } }
    else
      { legend:, hint: { text: hint } }
    end
  end

  def patient_on_last_dose?
    patient.programme_status(
      programme,
      academic_year: session.academic_year
    ).on_last_dose?
  end
end
