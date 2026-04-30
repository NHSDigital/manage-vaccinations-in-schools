# frozen_string_literal: true

class PatientsClearRegistrationJob < ApplicationJob
  sidekiq_options queue: :patients

  def perform
    academic_year = AcademicYear.pending

    Patient
      .where(registration_academic_year: nil)
      .where.not(registration: nil)
      .or(Patient.where("registration_academic_year < ?", academic_year))
      .find_each do |patient|
        # We don't use update_all as that doesn't create an audit log.
        patient.update!(registration: nil, registration_academic_year: nil)
      end
  end
end
