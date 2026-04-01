# frozen_string_literal: true

class StatusGenerator::Consent
  def initialize(
    programme_type:,
    academic_year:,
    patient:,
    consents:,
    vaccination_records:,
    parents:
  )
    @programme_type = programme_type
    @academic_year = academic_year
    @patient = patient
    @consents = consents
    @vaccination_records = vaccination_records
    @parents = parents
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
              :parents

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
end
