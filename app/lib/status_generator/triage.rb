# frozen_string_literal: true

class StatusGenerator::Triage
  def initialize(
    programme_type:,
    academic_year:,
    patient:,
    consents:,
    triages:,
    vaccination_records:,
    parents:,
    sessions:,
    consent_notifications:
  )
    @programme_type = programme_type
    @academic_year = academic_year
    @patient = patient
    @consents = consents
    @triages = triages
    @vaccination_records = vaccination_records
    @parents = parents
    @sessions = sessions
    @consent_notifications = consent_notifications
  end

  def programme
    Programme.find(programme_type, disease_types:, patient:)
  end

  def status
    if status_should_be_safe_to_vaccinate?
      :safe_to_vaccinate
    elsif status_should_be_do_not_vaccinate?
      :do_not_vaccinate
    elsif status_should_be_delay_vaccination?
      :delay_vaccination
    elsif status_should_be_invite_to_clinic?
      :invite_to_clinic
    elsif status_should_be_required?
      :required
    else
      :not_required
    end
  end

  def vaccine_method
    latest_triage&.vaccine_method if status_should_be_safe_to_vaccinate?
  end

  def without_gelatine
    latest_triage&.without_gelatine if status_should_be_safe_to_vaccinate?
  end

  delegate :disease_types, to: :consent_generator

  def delay_vaccination_until_date
    if status_should_be_delay_vaccination?
      latest_triage&.delay_vaccination_until
    end
  end

  def consent_requires_triage?
    latest_consents.any?(&:requires_triage?)
  end

  def vaccination_history_requires_triage?
    return false unless programme.triage_on_vaccination_history?

    existing_records =
      vaccination_records.select { it.programme_type == programme_type }

    if programme.seasonal?
      existing_records.select! { it.academic_year == academic_year }
    end

    existing_records.any?(&:administered?) && !vaccinated?
  end

  private

  attr_reader :programme_type,
              :academic_year,
              :patient,
              :consents,
              :triages,
              :vaccination_records,
              :parents,
              :sessions,
              :consent_notifications

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

  def status_should_be_safe_to_vaccinate?
    return false if vaccinated?
    latest_triage&.safe_to_vaccinate?
  end

  def status_should_be_do_not_vaccinate?
    return false if vaccinated?
    latest_triage&.do_not_vaccinate?
  end

  def status_should_be_delay_vaccination?
    return false if vaccinated?
    latest_triage&.delay_vaccination? && !latest_triage.expired?
  end

  def status_should_be_invite_to_clinic?
    return false if vaccinated?
    latest_triage&.invite_to_clinic?
  end

  def status_should_be_required?
    return false if vaccinated?
    return true if latest_triage&.keep_in_triage?
    return true if latest_triage&.expired?

    return false if latest_consents.empty?

    consent_generator.status == :given &&
      (consent_requires_triage? || vaccination_history_requires_triage?)
  end

  def consent_generator
    @consent_generator ||=
      StatusGenerator::Consent.new(
        programme_type:,
        academic_year:,
        patient:,
        consents:,
        vaccination_records:,
        parents:,
        sessions:,
        consent_notifications:
      )
  end

  def latest_consents
    @latest_consents ||=
      ConsentGrouper.call(consents, programme_type:, academic_year:)
  end

  def latest_triage
    @latest_triage ||=
      TriageFinder.call(triages, programme_type:, academic_year:)
  end
end
