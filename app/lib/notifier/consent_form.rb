# frozen_string_literal: true

class Notifier::ConsentForm
  def initialize(consent_form)
    @consent_form = consent_form
  end

  def send_confirmation
    if consent_form.response_given?
      ProgrammeGrouper
        .call(consent_form.given_consent_form_programmes)
        .each_value do |consent_form_programmes|
          programme_types = consent_form_programmes.map(&:programme_type)
          disease_types =
            consent_form_programmes.flat_map(&:disease_types).uniq.presence
          send_confirmation_given(programme_types:, disease_types:)
        end

      ProgrammeGrouper
        .call(consent_form.refused_consent_form_programmes)
        .each_value do |consent_form_programmes|
          programme_types = consent_form_programmes.map(&:programme_type)
          disease_types =
            consent_form_programmes.flat_map(&:disease_types).uniq.presence
          send_confirmation_refused(programme_types:, disease_types:)
        end
    else
      send_confirmation_refused
    end
  end

  def send_unknown_contact_details_warning(patient:)
    patient.parents.each do |parent|
      params = {
        "consent_form_id" => consent_form.id,
        "parent_id" => parent.id,
        "patient_id" => patient.id
      }

      if parent.email.present?
        EmailDeliverySidekiqJob.perform_async(
          "consent_unknown_contact_details_warning",
          params
        )
      end

      next unless parent.phone.present? && parent.phone_receive_updates

      SMSDeliverySidekiqJob.perform_async(
        "consent_unknown_contact_details_warning",
        params
      )
    end
  end

  private

  attr_reader :consent_form

  def send_confirmation_given(programme_types: nil, disease_types: nil)
    params = { "consent_form_id" => consent_form.id }
    params["programme_types"] = programme_types if programme_types
    params["disease_types"] = disease_types if disease_types

    if consent_form.health_answers_require_triage?
      EmailDeliverySidekiqJob.perform_async(
        "consent_confirmation_triage",
        params
      )
    elsif consent_form.session&.clinic? || consent_form.session&.completed?
      EmailDeliverySidekiqJob.perform_async(
        "consent_confirmation_clinic",
        params
      )
    else
      EmailDeliverySidekiqJob.perform_async(
        "consent_confirmation_given",
        params
      )

      if consent_form.parent_phone_receive_updates
        SMSDeliverySidekiqJob.perform_async(
          "consent_confirmation_given",
          params
        )
      end
    end
  end

  def send_confirmation_refused(programme_types: nil, disease_types: nil)
    params = { "consent_form_id" => consent_form.id }
    params["programme_types"] = programme_types if programme_types
    params["disease_types"] = disease_types if disease_types

    EmailDeliverySidekiqJob.perform_async(
      "consent_confirmation_refused",
      params
    )

    if consent_form.parent_phone_receive_updates
      SMSDeliverySidekiqJob.perform_async(
        "consent_confirmation_refused",
        params
      )
    end
  end
end
