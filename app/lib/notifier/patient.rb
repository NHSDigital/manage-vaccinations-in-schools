# frozen_string_literal: true

class Notifier::Patient
  extend ActiveSupport::Concern

  CONSENT_REMINDER_TYPES = %i[initial_reminder subsequent_reminder].freeze

  def initialize(patient)
    @patient = patient
  end

  ##
  # Determine whether a consent request can be sent to the parents of this
  # patient.
  def can_send_consent_request?(programmes, academic_year:)
    programmes.any? do |programme|
      programme_status = patient.programme_status(programme, academic_year:)

      programme_status.needs_consent_no_response? ||
        programme_status.needs_consent_request_scheduled? ||
        programme_status.needs_consent_request_not_scheduled?
    end
  end

  ##
  # Send a consent request email and SMS to the parents of this patient.
  def send_consent_request(
    programmes,
    sent_by:,
    session: nil,
    team_location: nil
  )
    send_consent_notification(
      programmes,
      type: :request,
      sent_by:,
      session:,
      team_location:
    )
  end

  ##
  # Send a consent reminder email and SMS to the parents of this patient.
  #
  # This determines whether to send the initial reminder or subsequent
  # reminder based on what has already been sent to this patient.
  def send_consent_reminder(programmes, session:, sent_by:)
    already_sent_initial_reminder =
      programmes.all? do |programme|
        patient
          .consent_notifications
          .select { it.programmes.include?(programme) }
          .any?(&:initial_reminder?)
      end

    type =
      already_sent_initial_reminder ? :subsequent_reminder : :initial_reminder

    send_consent_notification(programmes, type:, session:, sent_by:)
  end

  ##
  # Determine whether a clinic invitation can be sent to the parents of this
  # patient.
  #
  # Normally this would be +true+, but it can be +false+ in some scenarios,
  # for example, if the patient has no parent contact details or has already
  # been invited to the clinic.
  def can_send_clinic_invitation?(
    programmes,
    team:,
    academic_year:,
    include_vaccinated_programmes: false,
    include_already_invited_programmes: true
  )
    return false unless send_notification?(team:)

    programmes_to_send_for =
      programmes_to_send_clinic_invitation_for(
        programmes,
        team:,
        academic_year:,
        include_vaccinated_programmes:,
        include_already_invited_programmes:
      )

    programmes_to_send_for.present?
  end

  ##
  # Send a clinic initiation email and SMS to the parents of this patient.
  #
  # This determines the correct type of invitation to use (either an initial
  # invitation or a subsequent invitation) based on the previous invitations
  # which have been sent:
  #
  # +include_vaccinated_programmes+ allows for the sending of invitations for
  # programmes where the patient has already been vaccinated.
  #
  # +include_already_invited_programmes+ allows for the sending of invitations
  # for programmes where the patient has already been invited for in the past.
  #
  def send_clinic_invitation(
    programmes,
    team:,
    academic_year:,
    sent_by:,
    include_vaccinated_programmes: false,
    include_already_invited_programmes: true
  )
    return unless send_notification?(team:)

    programmes_to_send_for =
      programmes_to_send_clinic_invitation_for(
        programmes,
        team:,
        academic_year:,
        include_vaccinated_programmes:,
        include_already_invited_programmes:
      )

    return if programmes_to_send_for.empty?

    type =
      if patient.invited_to_clinic?(
           programmes_to_send_for,
           team:,
           academic_year:
         )
        :subsequent_invitation
      else
        :initial_invitation
      end

    programme_types = programmes_to_send_for.map(&:type)

    clinic_notification =
      ClinicNotification.create!(
        patient:,
        programme_types:,
        team:,
        academic_year:,
        type:,
        sent_at: Time.current,
        sent_by:
      )

    template_name = find_clinic_template_name(type, team:)

    params = { academic_year:, patient:, programme_types:, sent_by:, team: }

    parents.each do |parent|
      EmailDeliveryJob.perform_later(template_name, parent:, **params)
      SMSDeliveryJob.perform_later(template_name, parent:, **params)
    end

    clinic_notification
  end

  private

  attr_reader :patient

  def send_notification?(team:)
    patient.send_notifications?(team:) && parents.present?
  end

  def parents
    @parents ||= patient.parents.select(&:contactable?).uniq
  end

  def filter_programmes_notify_parents(programmes)
    programmes.select do |programme|
      patient.vaccination_records.none? do
        it.notify_parents == false && it.programme == programme
      end
    end
  end

  def send_consent_notification(
    programmes,
    type:,
    sent_by:,
    session: nil,
    team_location: nil
  )
    if session.nil? && team_location.nil?
      raise "Either session or team_location must be set."
    end

    team_location ||= session.team_location

    team = team_location.team

    return unless send_notification?(team:)

    programmes_to_send_for = filter_programmes_notify_parents(programmes)

    return if programmes_to_send_for.empty?

    consent_notification =
      ConsentNotification.create!(
        programmes: programmes_to_send_for,
        patient:,
        session:,
        team_location:,
        type:,
        sent_at: Time.current,
        sent_by:
      )

    location = team_location.location
    outbreak = session&.outbreak || false

    email_template, sms_template =
      generate_consent_templates(
        programmes: programmes_to_send_for,
        patient:,
        location:,
        outbreak:,
        type:
      )

    programme_types = programmes_to_send_for.map(&:type)
    disease_types = programmes_to_send_for.flat_map(&:disease_types).presence

    parents.each do |parent|
      params = { disease_types:, parent:, patient:, programme_types:, sent_by: }

      if session
        params[:session] = session
      else
        params[:team_location] = team_location
      end

      EmailDeliveryJob.perform_later(email_template, **params)
      SMSDeliveryJob.perform_later(sms_template, **params)
    end

    PatientStatusUpdaterJob.perform_async(patient.id)

    consent_notification
  end

  def generate_consent_templates(
    programmes:,
    patient:,
    location:,
    outbreak:,
    type:
  )
    is_school = location.gias_school?

    base_template =
      if is_school && CONSENT_REMINDER_TYPES.include?(type)
        :consent_school_reminder
      else
        :"consent_#{is_school ? "school" : "clinic"}_#{type}"
      end

    # We can only handle a single programme group or variant in the template.
    group = ProgrammeGrouper.call(programmes).keys.sole
    variant =
      if programmes.count == 1
        programmes.sole.variant_for(patient:).variant_type
      end

    email_template =
      if is_school
        template =
          resolve_consent_template(
            base_template:,
            group:,
            variant:,
            outbreak:,
            channel: :email
          )
        if template.blank?
          raise(
            "Missing email template for consent notification: #{base_template} " \
              "with group=#{group.inspect} variant=#{variant.inspect} " \
              "outbreak=#{is_outbreak.inspect}"
          )
        end
        template
      else
        base_template
      end

    sms_template =
      if type == :request
        template =
          resolve_consent_template(
            base_template:,
            group:,
            variant:,
            outbreak:,
            channel: :sms
          )
        template || base_template
      elsif is_school
        :consent_school_reminder
      end

    [email_template, sms_template]
  end

  def resolve_consent_template(
    base_template:,
    group:,
    variant:,
    outbreak:,
    channel:
  )
    combinations = [([group, :outbreak] if outbreak), [group]]
    if variant.present? && variant != group
      combinations.prepend(([variant, :outbreak] if outbreak), [variant])
    end
    combinations.compact!

    combinations
      .lazy
      .map { |parts| :"#{base_template}_#{parts.join("_")}" }
      .detect { NotifyTemplate.exists?(it, channel:) }
  end

  def programmes_to_send_clinic_invitation_for(
    programmes,
    team:,
    academic_year:,
    include_vaccinated_programmes: false,
    include_already_invited_programmes: true
  )
    filter_programmes_notify_parents(programmes).select do |programme|
      programme_status = patient.programme_status(programme, academic_year:)

      next false if programme_status.not_eligible?

      if !include_vaccinated_programmes && programme_status.vaccinated?
        next false
      end

      if !include_already_invited_programmes &&
           patient.invited_to_clinic?([programme], team:, academic_year:)
        next false
      end

      true
    end
  end

  def find_clinic_template_name(type, team:)
    template_names = [
      :"clinic_#{type}_#{team.organisation.ods_code.downcase}",
      :"clinic_#{type}"
    ]

    template_names.find { NotifyTemplate.exists?(it, channel: :email) }
  end
end
