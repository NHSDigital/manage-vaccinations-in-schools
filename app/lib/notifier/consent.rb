# frozen_string_literal: true

class Notifier::Consent
  extend ActiveSupport::Concern

  def initialize(consent)
    @consent = consent
  end

  def send_confirmation(session:, triage:, sent_by:)
    return unless send_notification?

    params = {
      "consent_id" => consent.id,
      "session_id" => session.id,
      "sent_by_user_id" => sent_by.id
    }

    if triage
      send_triage_email(triage, session, params)
    elsif consent.requires_triage?
      send_consent_email(:triage, params)
    elsif consent.response_refused?
      send_consent_email_and_sms(:refused, consent, params)
    elsif consent.response_given?
      send_consent_email_and_sms(:given, consent, params)
    end
  end

  private

  attr_reader :consent

  delegate :patient, :programme, to: :consent

  def send_notification?
    patient.send_notifications?(team: consent.team, send_to_archived: true) &&
      !consent.via_self_consent?
  end

  def send_triage_email(triage, session, params)
    template_name = triage_email_template(triage, session)
    EmailDeliverySidekiqJob.perform_async(template_name, params)
  end

  def triage_email_template(triage, session)
    if triage.safe_to_vaccinate?
      if programme.mmr? && patient_on_last_dose?(session)
        "triage_vaccination_will_happen_mmr_second_dose"
      else
        "triage_vaccination_will_happen"
      end
    elsif triage.do_not_vaccinate?
      "triage_vaccination_wont_happen"
    elsif triage.delay_vaccination?
      "triage_delay_vaccination"
    elsif triage.invite_to_clinic?
      resolve_email_template("triage_vaccination_at_clinic", triage.team)
    elsif triage.keep_in_triage?
      "consent_confirmation_triage"
    end
  end

  def send_consent_email(type, params)
    template_name = "consent_confirmation_#{type}"
    EmailDeliverySidekiqJob.perform_async(template_name, params)
  end

  def send_consent_sms(type, consent, params)
    if consent.parent.phone_receive_updates
      template_name = "consent_confirmation_#{type}"
      SMSDeliverySidekiqJob.perform_async(template_name, params)
    end
  end

  def send_consent_email_and_sms(type, consent, params)
    send_consent_email(type, params)
    send_consent_sms(type, consent, params)
  end

  def resolve_email_template(template_name, team)
    ods_code = team.organisation.ods_code.downcase
    template_names = ["#{template_name}_#{ods_code}", template_name]
    template_names.find { NotifyTemplate.exists?(it, channel: :email) }
  end

  def patient_on_last_dose?(session)
    patient
      .reload
      .programme_status(programme, academic_year: session.academic_year)
      .on_last_dose?
  end
end
