# frozen_string_literal: true

class StatusGenerator::Consent
  def initialize(
    programme_type:,
    academic_year:,
    patient:,
    consents:,
    vaccination_records:,
    parents:,
    sessions:,
    consent_notifications:,
    notify_log_entries:
  )
    @programme_type = programme_type
    @academic_year = academic_year
    @patient = patient
    @consents = consents
    @vaccination_records = vaccination_records
    @parents = parents
    @sessions = sessions
    @consent_notifications = consent_notifications
    @notify_log_entries = notify_log_entries
  end

  def programme
    Programme.find(programme_type, disease_types:, patient:)
  end

  def status
    if status_should_be_given?
      :given
    elsif status_should_be_refused?
      :refused
    elsif status_should_be_follow_up_requested?
      :follow_up_requested
    elsif status_should_be_conflicts?
      :conflicts
    elsif status_should_be_no_contact_details?
      :no_contact_details
    elsif status_should_be_request_scheduled?
      :request_scheduled
    elsif status_should_be_request_not_scheduled?
      :request_not_scheduled
    elsif status_should_be_request_failed?
      :request_failed
    elsif status_should_be_no_response?
      :no_response
    else
      :not_required
    end
  end

  def date
    consents_for_status.map(&:submitted_at).max.to_date
  end

  def vaccine_methods
    status_should_be_given? ? agreed_vaccine_methods : []
  end

  def without_gelatine
    status_should_be_given? ? agreed_without_gelatine : nil
  end

  def disease_types
    status_should_be_given? ? agreed_disease_types : []
  end

  private

  attr_reader :programme_type,
              :academic_year,
              :patient,
              :consents,
              :vaccination_records,
              :parents,
              :sessions,
              :consent_notifications,
              :notify_log_entries

  def vaccinated?
    return @vaccinated if defined?(@vaccinated)

    @vaccinated =
      VaccinationCriteria.new(
        programme_type:,
        academic_year:,
        patient:,
        vaccination_records:
      ).vaccinated?
  end

  def status_should_be_given?
    return false if vaccinated?
    return false if conflicting_disease_types?

    consents_for_status.any? && consents_for_status.all?(&:response_given?) &&
      agreed_vaccine_methods.present?
  end

  def conflicting_disease_types?
    consents_for_status.filter_map(&:disease_types).map(&:sort).uniq.size > 1
  end

  def status_should_be_refused?
    return false if vaccinated?

    latest_consents.any? && latest_consents.all?(&:hard_refusal?)
  end

  def status_should_be_follow_up_requested?
    return false if vaccinated?

    # Follow-up is the outcome when there are no outright refusals and at least
    # one consent has follow_up_requested — including the case where one parent
    # has given consent and another has asked for a follow-up discussion,
    # because that discussion could change the outcome to :given.
    consents_for_status.any? && consents_for_status.none?(&:hard_refusal?) &&
      consents_for_status.any?(&:refusal_with_follow_up?)
  end

  def status_should_be_conflicts?
    return false if vaccinated?

    consents_for_status =
      (self_consents.any? ? self_consents : parental_consents)

    has_given = consents_for_status.any?(&:response_given?)
    has_hard_refusal = consents_for_status.any?(&:hard_refusal?)
    has_follow_up = consents_for_status.any?(&:refusal_with_follow_up?)

    return true if has_given && has_hard_refusal

    # hard refusal + follow_up is a conflict: even if the follow-up
    # resolves to given, the outstanding refusal remains unresolved
    return true if has_hard_refusal && has_follow_up

    consents_for_status.any? && consents_for_status.all?(&:response_given?) &&
      (agreed_vaccine_methods.blank? || conflicting_disease_types?)
  end

  def status_should_be_no_response? = !vaccinated?

  def status_should_be_no_contact_details?
    parents.none?(&:contactable?)
  end

  def status_should_be_request_scheduled?
    return false if vaccinated?

    parents_contactable? && consent_notifications.empty? &&
      sessions.any? { consent_request_scheduled_in_future?(it) }
  end

  def status_should_be_request_not_scheduled?
    return false if vaccinated?

    parents_contactable? && consent_notifications.empty? &&
      (sessions.empty? || sessions.any? { consent_request_not_scheduled?(it) })
  end

  def status_should_be_request_failed?
    relevant_entries = notify_log_entries.select { relevant_notify_entry?(it) }

    relevant_entries.present? &&
      relevant_entries.all? { it.delivery_status.to_s.include?("failure") }
  end

  def agreed_vaccine_methods
    @agreed_vaccine_methods ||=
      consents_for_status.map(&:vaccine_methods).inject(&:intersection)
  end

  def agreed_disease_types
    @agreed_disease_types ||=
      consents_for_status.filter_map(&:disease_types).inject(&:intersection)
  end

  def agreed_without_gelatine
    @agreed_without_gelatine ||= consents_for_status.any?(&:without_gelatine)
  end

  def consents_for_status
    @consents_for_status ||=
      self_consents.any? ? self_consents : parental_consents
  end

  def self_consents
    @self_consents ||= latest_consents.select(&:via_self_consent?)
  end

  def parental_consents
    @parental_consents ||= latest_consents.reject(&:via_self_consent?)
  end

  def latest_consents
    @latest_consents ||=
      ConsentGrouper.call(consents, programme_type:, academic_year:)
  end

  def parents_contactable? = parents.any?(&:contactable?)

  def consent_request_scheduled_in_future?(session)
    send_at = session.send_consent_requests_at

    # Not using future? because it doesn't work with Timecop
    send_at.present? && send_at > Time.current
  end

  # Treat consent requests as not scheduled when send_consent_requests_at is
  # missing or has already passed, such as for sessions activated on the
  # same day they are created.
  def consent_request_not_scheduled?(session)
    send_at = session.send_consent_requests_at
    send_at.nil? || send_at < Time.current
  end

  def relevant_notify_entry?(entry)
    date_range = academic_year.to_academic_year_date_range

    entry.patient_id == patient.id &&
      date_range.cover?(entry.created_at.to_date) &&
      notify_log_entry_matches_programme_type?(entry)
  end

  def notify_log_entry_matches_programme_type?(entry)
    entry.notify_log_entry_programmes.any? do |programme|
      programme.programme_type == programme_type
    end
  end
end
