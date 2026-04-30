# frozen_string_literal: true

class PatientNHSNumberLookupSidekiqJob < ApplicationJobSidekiq
  include PDSThrottlingConcern

  sidekiq_options queue: :pds

  def perform(patient_id)
    patient = Patient.find(patient_id)
    PatientNHSNumberLookupJob.new.perform(patient)
  end
end
