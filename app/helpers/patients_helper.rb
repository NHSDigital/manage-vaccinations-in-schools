# frozen_string_literal: true

module PatientsHelper
  # Replace each space in NHS number with a non-breaking space and
  # zero-width word joiner to prevent telephone format detection
  def patient_nhs_number(patient)
    format_nhs_number(patient.nhs_number, invalid: patient.try(:invalidated?))
  end

  def format_nhs_number(nhs_number, invalid: false)
    span =
      if nhs_number.blank?
        "Not provided"
      else
        tag.span(class: %w[app-u-code nhsuk-u-nowrap]) do
          nhs_number.to_s.gsub(/(\d{3})(\d{3})(\d{4})/, "\\1 \\2 \\3").html_safe
        end
      end

    invalid ? tag.s(span) : span
  end

  def patient_date_of_birth(patient)
    "#{patient.date_of_birth.to_fs(:long)} (aged #{patient.age_years})"
  end

  def patient_outstanding_programmes(patient, session:)
    registration_status = patient.registration_status(session:)
    programmes = session.programmes_for(patient:)

    if registration_status.nil? || registration_status.unknown? ||
         registration_status.not_attending?
      return []
    end

    any_programme_exists =
      patient.vaccination_records.for_programmes(programmes).exists?(session:)

    # If this patient hasn't been seen yet by a nurse for any of the programmes,
    # we don't want to show the banner.
    return [] unless any_programme_exists

    academic_year = session.academic_year

    programmes.select do |programme|
      !patient.vaccination_records.for_programme(programme).exists?(session:) &&
        patient.consent_given_and_safe_to_vaccinate?(programme:, academic_year:)
    end
  end

  def patient_school(patient)
    patient&.school&.name || "Unknown school"
  end

  def patient_year_group(patient, academic_year:)
    str = format_year_group(patient.year_group(academic_year:))

    include_registration =
      patient.registration_academic_year == academic_year &&
        patient.registration.present?

    include_academic_year =
      academic_year != AcademicYear.current ||
        AcademicYear.current != AcademicYear.pending

    str = str.dup if include_registration || include_academic_year

    str << ", #{patient.registration}" if include_registration

    if include_academic_year
      str << " (#{format_academic_year(academic_year)} academic year)"
    end

    str
  end

  def patient_parents(patient)
    format_parents_with_relationships(patient.parent_relationships)
  end

  def patient_needs_more_doses?(patient, programme, academic_year)
    patient.programme_status(programme, academic_year:).needs_more_doses?
  end

  def patient_next_dose_label(patient, programme, academic_year)
    patient
      .programme_status(programme, academic_year:)
      .dose_sequence
      &.ordinalize
  end
end
