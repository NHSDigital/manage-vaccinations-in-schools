# frozen_string_literal: true

class GovukNotifyPersonalisation
  class ConsentDetailsPresenter
    include Rails.application.routes.url_helpers

    def initialize(personalisation)
      @personalisation = personalisation
    end

    attr_reader :personalisation

    delegate :consent,
             :consent_form,
             :host,
             :patient,
             :programmes,
             :session,
             :short_patient_name,
             :team_location,
             to: :personalisation

    def consent_deadline
      session&.consent_deadline_date&.to_fs(:short_day_of_week)
    end

    def consent_link
      return nil if (session.nil? && team_location.nil?) || programmes.empty?

      programme_params =
        programmes.flat_map { it.variant_for(patient:).to_param }

      host +
        start_parent_interface_consent_forms_path(
          session || team_location,
          programme_params.join("-")
        )
    end

    def consented_vaccine_methods_message
      return if consent.nil? && consent_form.nil?

      consent_form_programmes =
        (consent ? [consent] : consent_form.consent_form_programmes)

      consent_programmes = consent_form_programmes.map(&:programme)

      consented_vaccine_methods =
        if consent_programmes.any?(&:has_multiple_vaccine_methods?)
          if consent_form_programmes.any?(&:vaccine_method_injection_and_nasal?)
            "nasal spray flu vaccine, or the injected flu vaccine if the nasal spray is not suitable"
          elsif consent_form_programmes.any?(&:vaccine_method_nasal?)
            "nasal spray flu vaccine"
          else
            "injected flu vaccine"
          end
        elsif consent_programmes.any?(&:vaccine_may_contain_gelatine?)
          if consent_form_programmes.any?(&:without_gelatine)
            "vaccine without gelatine"
          end
        end

      return "" if consented_vaccine_methods.nil?

      "You’ve agreed for #{short_patient_name} to have the #{consented_vaccine_methods}."
    end

    def follow_up_discussion
      consent_form&.follow_up_requested
    end

    def reason_for_refusal
      reason = consent_form&.reason_for_refusal || consent&.reason_for_refusal
      return if reason.nil?

      I18n.t(reason, scope: "mailers.consent_form_mailer.reasons_for_refusal")
    end

    def survey_deadline_date
      recorded_at = consent_form&.recorded_at || consent&.created_at
      return if recorded_at.nil?

      (recorded_at + 7.days).to_date.to_fs(:long)
    end

    def talk_to_your_child_message
      return nil if patient.nil?
      return "" if patient.year_group(academic_year:) <= 6

      [
        "## Talk to your child about what they want",
        "We suggest you talk to your child about the vaccination before you respond to us. " \
          "Young people have the right to refuse vaccinations.",
        "They also have [the right to consent to their own vaccinations]" \
          "(https://www.nhs.uk/conditions/consent-to-treatment/children/) " \
          "if they show they fully understand what’s involved. Our team might give young " \
          "people this opportunity if they assess them as suitably competent."
      ].join("\n\n")
    end

    private

    def academic_year
      personalisation.academic_year
    end
  end
end
