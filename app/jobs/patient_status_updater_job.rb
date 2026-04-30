# frozen_string_literal: true

class PatientStatusUpdaterJob < ApplicationJob
  sidekiq_options queue: :cache, lock: :until_executed

  def perform(patient_id = nil)
    academic_years = [AcademicYear.current, AcademicYear.pending].uniq
    patient = (patient_id ? Patient.find(patient_id) : nil)
    PatientStatusUpdater.call(patient:, academic_years:)
  end
end
