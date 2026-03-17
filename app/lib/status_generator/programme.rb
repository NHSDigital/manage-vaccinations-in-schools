# frozen_string_literal: true

class StatusGenerator::Programme
  ##
  # Creates a new instance of the status generator used to determine the
  # programme status of a patient.
  #
  # The `consents`, `triages` and `vaccination_records` arguments are expected
  # to already be sorted in reverse chronological order, meaning the most
  # recent item is at the beginning of the array.
  def initialize(
    programme_type:,
    academic_year:,
    patient:,
    patient_locations:,
    consents:,
    triages:,
    attendance_record:,
    vaccination_records:
  )
    @programme_type = programme_type
    @academic_year = academic_year
    @patient = patient
    @patient_locations = patient_locations
    @consents = consents
    @triages = triages
    @attendance_record = attendance_record

    @vaccination_criteria =
      VaccinationCriteria.new(
        programme_type:,
        academic_year:,
        patient:,
        vaccination_records:
      )
  end

  def programme
    Programme.find(programme_type, disease_types:, patient:)
  end

  def status
    if should_be_vaccinated_already?
      :vaccinated_already
    elsif should_be_vaccinated_fully?
      :vaccinated_fully
    elsif should_be_cannot_vaccinate_unwell?
      :cannot_vaccinate_unwell
    elsif should_be_cannot_vaccinate_refused?
      :cannot_vaccinate_refused
    elsif should_be_cannot_vaccinate_contraindicated?
      :cannot_vaccinate_contraindicated
    elsif should_be_cannot_vaccinate_absent?
      :cannot_vaccinate_absent
    elsif should_be_cannot_vaccinate_do_not_vaccinate?
      :cannot_vaccinate_do_not_vaccinate
    elsif should_be_needs_consent_no_response?
      :needs_consent_no_response
    elsif should_be_cannot_vaccinate_delay_vaccination?
      :cannot_vaccinate_delay_vaccination
    elsif should_be_due?
      :due
    elsif should_be_needs_triage?
      :needs_triage
    elsif should_be_has_refusal_consent_conflicts?
      :has_refusal_consent_conflicts
    elsif should_be_has_refusal_consent_refused?
      :has_refusal_consent_refused
    elsif should_be_needs_consent_follow_up_requested?
      :needs_consent_follow_up_requested
    elsif should_be_needs_consent_request_failed?
      :needs_consent_request_failed
    elsif should_be_needs_consent_request_scheduled?
      :needs_consent_request_scheduled
    elsif should_be_needs_consent_request_not_scheduled?
      :needs_consent_request_not_scheduled
    else
      :not_eligible
    end
  end

  def disease_types
    return nil if not_eligible?

    if vaccinated_vaccination_record
      vaccinated_vaccination_record.disease_types
    elsif consent_status.in?(%i[given refused conflicts])
      consent_generator.disease_types
    end
  end

  def dose_sequence
    return unless is_eligible?

    # Patients receive dose 5 of Td/IPV by default, regardless of vaccination history
    return 5 if programme.td_ipv?

    valid_vaccination_records.count + 1
  end

  def without_gelatine
    if not_eligible? ||
         triage_generator.status.in?(
           %i[required invite_to_clinic do_not_vaccinate]
         ) ||
         consent_status.in?(
           %i[no_response conflicts refused follow_up_requested]
         )
      return nil
    end

    triage_generator.without_gelatine || consent_generator.without_gelatine
  end

  def vaccine_methods
    if not_eligible? ||
         triage_generator.status.in?(
           %i[required invite_to_clinic do_not_vaccinate]
         ) ||
         consent_status.in?(
           %i[no_response conflicts refused follow_up_requested]
         )
      return nil
    end

    if triage_generator.vaccine_method
      [triage_generator.vaccine_method]
    else
      consent_vaccine_methods
    end
  end

  def date
    if (
         delay_vaccination_until_date =
           triage_generator.delay_vaccination_until_date
       )
      delay_vaccination_until_date
    elsif vaccinated_vaccination_record
      vaccinated_vaccination_record.performed_at_date
    elsif is_absent?
      attendance_record.date
    else
      vaccination_records.map(&:performed_at_date).max
    end
  end

  def location_id
    vaccinated_vaccination_record&.location_id
  end

  def consent_status
    consent_generator.status
  end

  def consent_vaccine_methods
    consent_generator.vaccine_methods
  end

  private

  attr_reader :programme_type,
              :academic_year,
              :patient,
              :patient_locations,
              :consents,
              :triages,
              :attendance_record,
              :vaccination_criteria

  delegate :vaccinated?,
           :vaccinated_vaccination_record,
           :valid_vaccination_records,
           :vaccination_records,
           to: :vaccination_criteria

  def should_be_vaccinated_already?
    vaccinated_vaccination_record&.already_had?
  end

  def should_be_vaccinated_fully? = vaccinated?

  def should_be_cannot_vaccinate_unwell?
    is_eligible? && vaccination_records&.first&.unwell? && date.today?
  end

  def should_be_cannot_vaccinate_refused?
    is_eligible? && vaccination_records&.first&.refused? && date.today?
  end

  def should_be_cannot_vaccinate_contraindicated?
    is_eligible? && vaccination_records&.first&.contraindicated? && date.today?
  end

  def should_be_cannot_vaccinate_absent?
    is_eligible? && is_absent? && date.today?
  end

  def should_be_cannot_vaccinate_do_not_vaccinate?
    is_eligible? && triage_generator.status == :do_not_vaccinate
  end

  def should_be_needs_consent_no_response?
    is_eligible? && consent_status == :no_response
  end

  def should_be_cannot_vaccinate_delay_vaccination?
    is_eligible? && triage_generator.status == :delay_vaccination
  end

  def should_be_due? = is_due?

  def should_be_needs_triage?
    triage_generator.status.in?(%i[required invite_to_clinic])
  end

  def should_be_has_refusal_consent_conflicts?
    consent_status == :conflicts
  end

  def should_be_has_refusal_consent_refused?
    consent_status == :refused
  end

  def should_be_needs_consent_follow_up_requested?
    consent_status == :follow_up_requested
  end

  def should_be_needs_consent_request_failed?
    false # TODO: Implement this status.
  end

  def should_be_needs_consent_request_scheduled?
    false # TODO: Implement this status.
  end

  def should_be_needs_consent_request_not_scheduled?
    false # TODO: Implement this status.
  end

  def year_group = patient.year_group(academic_year:)

  def is_eligible?
    # Eligibility is normally determined by the default year groups of the
    # programme; however, there are some cases where the location has an
    # override set. This is often the case for flu in SEN schools.

    return @is_eligible if defined?(@is_eligible)

    @is_eligible =
      default_programme_year_groups.include?(year_group) ||
        patient_locations
          .select { it.academic_year == academic_year }
          .any? do |patient_location|
            patient_location.location.location_programme_year_groups.any? do
              it.programme_type == programme_type &&
                it.academic_year == academic_year && it.year_group == year_group
            end
          end
  end

  def not_eligible?
    # This is more than just checking whether the patient is not eligible, in
    # case somehow they were vaccinated anyway.
    !vaccinated? && !is_eligible?
  end

  def is_due?
    is_eligible? && consent_generator.status == :given &&
      triage_generator.status.in?(%i[safe_to_vaccinate not_required])
  end

  def is_absent? = attendance_record&.attending == false

  def default_programme_year_groups
    # We can't use `programme` here because it introduces a circular
    # dependency on `disease_types`.
    Programme.find(programme_type).default_year_groups
  end

  def consent_generator
    @consent_generator ||=
      StatusGenerator::Consent.new(
        programme_type:,
        academic_year:,
        patient:,
        consents:,
        vaccination_records:
      )
  end

  def triage_generator
    @triage_generator ||=
      StatusGenerator::Triage.new(
        programme_type:,
        academic_year:,
        patient:,
        consents:,
        triages:,
        vaccination_records:
      )
  end
end
