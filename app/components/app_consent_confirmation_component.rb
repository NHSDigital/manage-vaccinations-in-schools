# frozen_string_literal: true

class AppConsentConfirmationComponent < ViewComponent::Base
  erb_template <<-ERB
    <%= govuk_panel(title_text: title, text: panel_text) %>

    <p>We've sent a confirmation to <%= parent_email %></p>
  ERB

  def initialize(consent_form)
    @consent_form = consent_form
  end

  def title
    if response_given?
      if refused_consent_form_programmes.empty?
        "Consent confirmed"
      else
        "Consent for the #{given_vaccinations} confirmed"
      end
    elsif follow_up_requested?
      "You've asked for a follow-up"
    else
      "Consent refused"
    end
  end

  private

  attr_reader :consent_form

  delegate :given_consent_form_programmes,
           :refused_consent_form_programmes,
           :response_given?,
           :parent_email,
           to: :consent_form

  delegate :govuk_panel, to: :helpers

  def full_name = consent_form.full_name(context: :parents)

  def follow_up_requested?
    refused_consent_form_programmes.any?(&:follow_up_requested?)
  end

  def panel_text
    location = (consent_form.education_setting_school? ? " at school" : "")

    if response_given?
      if consent_form.health_answers_require_triage?
        <<-END_OF_TEXT
          As you answered ‘yes’ to some of the health questions, we need to check
          the #{given_vaccinations_are} suitable for #{full_name}. We’ll review
          your answers and get in touch again soon.
        END_OF_TEXT
      else
        "#{full_name} is due to get the #{given_vaccinations}#{location}" +
          (dates.present? ? " on #{dates}" : "")
      end
    elsif follow_up_requested?
      "A member of the team will contact you soon to discuss your options."
    else
      "You’ve told us that you do not want #{full_name} to get the" \
        " #{refused_vaccinations}#{location}"
    end
  end

  def given_vaccinations = vaccinations_text(given_consent_form_programmes)

  def refused_vaccinations = vaccinations_text(refused_consent_form_programmes)

  def vaccinations_text(consent_form_programmes)
    programme_names =
      consent_form_programmes.map do |consent_form_programme|
        programme = consent_form_programme.programme

        if programme.has_multiple_vaccine_methods?
          vaccine_method = consent_form_programme.vaccine_methods.first
          method_prefix =
            Vaccine.human_enum_name(:method_prefix, vaccine_method)
          "#{method_prefix} #{programme.name_in_sentence}".lstrip
        else
          programme.name_in_sentence
        end
      end

    "#{programme_names.to_sentence} vaccination".pluralize(
      programme_names.count
    )
  end

  def given_vaccinations_are
    "#{given_vaccinations} #{given_consent_form_programmes.one? ? "is" : "are"}"
  end

  def dates
    if consent_form.session_dates_are_accurate?
      consent_form
        .session
        .today_or_future_dates
        .map { it.to_fs(:short_day_of_week) }
        .to_sentence(two_words_connector: " or ", last_word_connector: " or ")
    end
  end
end
