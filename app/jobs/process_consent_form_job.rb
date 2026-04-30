# frozen_string_literal: true

class ProcessConsentFormJob < ApplicationJob
  include PDSThrottlingConcern

  sidekiq_options queue: :consents

  # We may enqueue this job more than once for the same ConsentForm during the parent
  # consent journey (e.g. once when the consent is recorded, and again after the optional
  # ethnicity flow is completed). Sidekiq does not guarantee ordering, so those jobs
  # could otherwise run concurrently and race each other while reading/updating the
  # same ConsentForm/Patient (and while calling out to PDS).
  #
  # Throttling concurrency to 1 per consent_form ID ensures only one job for a given
  # ConsentForm is processed at a time. This makes the job safe to re-run to pick up
  # newly submitted data like ethnicity.
  sidekiq_throttle(
    concurrency: {
      limit: 1,
      key_suffix: ->(consent_form_id) { consent_form_id }
    }
  )

  def perform(consent_form_id)
    @consent_form =
      ConsentForm.includes(:consent_form_programmes).find(consent_form_id)

    if already_matched?
      # This covers the case where the job is re-run
      # after the ethnicity flow is completed.
      if (patient = @consent_form.matched_patient)
        patient.assign_ethnicity_from!(@consent_form)
      end

      return
    end

    begin
      if match_with_exact_nhs_number
        # Match if we find a patient with the PDS NHS number
      elsif location_patients.count == 1
        # If we found exactly one, match the consent form to this patient
        match_to_only_patient(location_patients.first)
      elsif pds_patient && matching_patients.empty?
        # If no patients are found, store the PDS NHS number in the consent form.
        # A nurse may then create a patient record and we can try this job again
        update_consent_form_nhs_number
      end

      # If we found:
      # - No patients with the NHS number from the PDS record
      # - 2 or more patients in the original session, matching with no NHS number
      # - 1 or more patients in any session, matching with no NHS number
      # Then do nothing; the nurse needs to match manually or create a new patient
    rescue NHS::PDS::InvalidSearchData, NHS::PDS::TooManyMatches => e
      Sentry.capture_exception(e, level: "warning")
    ensure
      send_confirmation_notification
    end
  end

  private

  def query
    {
      given_name: ApostropheNormaliser.call(@consent_form.given_name),
      family_name: ApostropheNormaliser.call(@consent_form.family_name),
      date_of_birth: @consent_form.date_of_birth,
      address_postcode: @consent_form.address_postcode
    }
  end

  def pds_patient
    @pds_patient ||= PDS::Patient.search(**query)
  end

  def already_matched? = @consent_form.matched?

  def match_with_exact_nhs_number
    return false unless pds_patient

    patient =
      Patient.includes(:school, :parents).find_by(
        nhs_number: pds_patient.nhs_number
      )
    return false unless patient

    patient.update_from_pds!(pds_patient)

    match_patient_to_consent_form(patient)

    true
  end

  def location_patients
    @location_patients ||=
      begin
        scope =
          Patient
            .joins(:patient_locations)
            .where(
              patient_locations: {
                location: @consent_form.location,
                academic_year: @consent_form.academic_year
              }
            )
            .includes(:school, :parents)

        PatientMatcher.from_relation(scope, nhs_number: nil, **query)
      end
  end

  def matching_patients
    @matching_patients ||=
      PatientMatcher.from_relation(
        Patient.includes(:school, :parents),
        nhs_number: nil,
        **query
      )
  end

  def update_consent_form_nhs_number
    @consent_form.update!(nhs_number: pds_patient.nhs_number)
  end

  def match_to_only_patient(patient)
    if pds_patient
      if patient.nhs_number.nil?
        # TODO: Can we take this opportunity to set the NHS number on the patient?
      elsif patient.nhs_number != pds_patient.nhs_number
        # We found a patient in PDS and we found one in Mavis using the same search
        # query, but the NHS numbers don't match.
        raise Patient::NHSNumberMismatch
      end
    end

    match_patient_to_consent_form(patient)
  end

  def match_patient_to_consent_form(patient)
    unless @consent_form.matches_contact_details_for?(patient:)
      @consent_form.notifier.send_unknown_contact_details_warning(patient:)
    end

    @consent_form.match_with_patient!(patient, current_user: nil)

    reset_counts
  end

  def reset_counts
    cached_counts = TeamCachedCounts.new(@consent_form.team)
    cached_counts.reset_unmatched_consent_responses!
    cached_counts.reset_school_moves!
  end

  def send_confirmation_notification
    unless @consent_form.confirmation_sent?
      @consent_form.notifier.send_confirmation
      @consent_form.confirmation_sent!
    end
  end
end
