# frozen_string_literal: true

class SMSDeliveryJob < NotifyDeliveryJob
  include NotifyThrottlingConcern

  PASSTHROUGH_TEMPLATE_ID = "c242b359-73d6-4b74-bda2-136093550636"

  INVALID_UK_MOBILE_NUMBER_ERROR = "InvalidPhoneError: Not a UK mobile number"

  def perform(
    template_name,
    academic_year: nil,
    consent: nil,
    consent_form: nil,
    disease_types: nil,
    parent: nil,
    patient: nil,
    programme_types: [],
    sent_by: nil,
    session: nil,
    team: nil,
    team_location: nil,
    vaccination_record: nil
  )
    template_name_sym = template_name.to_sym
    personalisation =
      GovukNotifyPersonalisation.new(
        academic_year:,
        consent:,
        consent_form:,
        disease_types:,
        parent:,
        patient:,
        programme_types:,
        session:,
        team:,
        team_location:,
        vaccination_record:
      )

    phone_number =
      phone_number_for(
        template_name,
        personalisation.parent,
        personalisation.consent_form
      )

    return if phone_number.nil?

    template = NotifyTemplate.find(template_name_sym, channel: :sms)
    raise UnknownTemplate if template.nil?

    rendered = template.render(personalisation)

    args = {
      personalisation: rendered.slice(:body),
      phone_number:,
      template_id: PASSTHROUGH_TEMPLATE_ID
    }

    delivery_id, delivery_status =
      if self.class.send_via_notify?
        begin
          [self.class.client.send_sms(**args).id, "sending"]
        rescue Notifications::Client::BadRequestError => e
          if !Rails.env.production? &&
               e.message.include?(TEAM_ONLY_API_KEY_MESSAGE)
            # Prevent retries and job failures.
            Sentry.capture_exception(e)
            [nil, "technical_failure"]
          elsif e.message == INVALID_UK_MOBILE_NUMBER_ERROR
            [nil, "not_uk_mobile_number_failure"]
          else
            raise
          end
        end
      elsif self.class.send_via_test?
        self.class.deliveries << args
        [SecureRandom.uuid, "delivered"]
      else
        Rails.logger.info "Sending SMS to #{phone_number} with template #{PASSTHROUGH_TEMPLATE_ID}"
        [nil, "delivered"]
      end

    NotifyLogEntry.create!(
      body: rendered[:body],
      consent_form: personalisation.consent_form,
      delivery_id:,
      delivery_status:,
      parent: personalisation.parent,
      patient: personalisation.patient,
      recipient: phone_number,
      sent_by:,
      template_id: template.id,
      type: :sms,
      purpose: NotifyLogEntry.purpose_for_template_name(template_name_sym),
      notify_log_entry_programmes_attributes:
        personalisation.programmes.map do
          { programme_type: it.type, disease_types: it.disease_types }
        end
    )
  end

  def self.phone_number_for(template_name, parent, consent_form = nil)
    if template_name == :consent_unknown_contact_details_warning
      parent&.phone
    else
      consent_form&.parent_phone || parent&.phone
    end
  end
end
