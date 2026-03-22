# frozen_string_literal: true

class EmailDeliveryJob < NotifyDeliveryJob
  include NotifyThrottlingConcern

  PASSTHROUGH_TEMPLATE_ID = "305a53f8-86eb-485e-85a5-328c9aabba45"

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

    email_address =
      if template_name_sym == :consent_unknown_contact_details_warning
        personalisation.parent&.email
      else
        personalisation.consent_form&.parent_email ||
          personalisation.parent&.email
      end

    return if email_address.nil?

    template = NotifyTemplate.find(template_name_sym, channel: :email)
    raise UnknownTemplate if template.nil?

    rendered = template.render(personalisation)

    args = {
      email_address:,
      personalisation: rendered.slice(:subject, :body),
      template_id: PASSTHROUGH_TEMPLATE_ID
    }

    if (
         email_reply_to_id =
           personalisation.subteam&.reply_to_id ||
             personalisation.team.reply_to_id
       )
      args[:email_reply_to_id] = email_reply_to_id
    end

    delivery_id =
      if self.class.send_via_notify?
        begin
          self.class.client.send_email(**args).id
        rescue Notifications::Client::BadRequestError => e
          if !Rails.env.production? &&
               e.message.include?(TEAM_ONLY_API_KEY_MESSAGE)
            # Prevent retries and job failures.
            Sentry.capture_exception(e)
          else
            raise
          end
        end
      elsif self.class.send_via_test?
        self.class.deliveries << args
        SecureRandom.uuid
      else
        Rails.logger.info "Sending email to #{email_address} with template #{PASSTHROUGH_TEMPLATE_ID}"
        nil
      end

    NotifyLogEntry.create!(
      body: rendered[:body],
      consent_form: personalisation.consent_form,
      delivery_id:,
      parent: personalisation.parent,
      patient: personalisation.patient,
      recipient: email_address,
      sent_by:,
      subject: rendered[:subject],
      template_id: template.id,
      type: :email,
      purpose: NotifyLogEntry.purpose_for_template_name(template_name_sym),
      notify_log_entry_programmes_attributes:
        personalisation.programmes.map do
          { programme_type: it.type, disease_types: it.disease_types }
        end
    )
  end
end
