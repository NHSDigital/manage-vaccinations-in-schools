# frozen_string_literal: true

class PatientsRefusedConsentAlreadyVaccinatedJob < ApplicationJobActiveJob
  queue_as :patients

  def perform
    return unless should_perform?

    programmes.each { |programme| handle_programme!(programme) }
  end

  private

  def programmes = Programme.all

  def academic_year = AcademicYear.current

  def should_perform? = AcademicYear.pending > academic_year

  def handle_programme!(programme)
    programme_type = programme.type

    ActiveRecord::Base.transaction do
      patients_with_consent_refused(programme).find_each do |patient|
        consents =
          ConsentGrouper.call(patient.consents, programme_type:, academic_year:)

        if should_record_already_vaccinated?(consents:)
          record_already_vaccinated!(patient, consents:)
        end
      end
    end
  end

  def patients_with_consent_refused(programme)
    Patient
      .includes(parent_relationships: :parent)
      .appear_in_programmes([programme], academic_year:)
      .has_programme_status(
        "has_refusal_consent_refused",
        programme:,
        academic_year:
      )
  end

  def should_record_already_vaccinated?(consents:)
    consents.all?(&:reason_for_refusal_already_vaccinated?)
  end

  def record_already_vaccinated!(patient, consents:)
    names =
      consents.map do |consent|
        "#{consent.name} (#{consent.who_responded.downcase_first})"
      end

    notes = "Self-reported by #{names.to_sentence}"
    performed_at = consents.map(&:submitted_at).min

    # We're assuming here that the consents all agree on the `disease_types`
    # and `programme_type`.
    latest_consent = consents.sort(&:submitted_at).last
    disease_types = latest_consent.disease_types
    programme_type = latest_consent.programme_type

    VaccinationRecord.create!(
      disease_types:,
      location_name: "Unknown",
      notes:,
      outcome: "already_had",
      patient:,
      performed_at:,
      programme_type:,
      source: "consent_refusal"
    )

    PatientStatusUpdater.call(patient:)
  end
end
