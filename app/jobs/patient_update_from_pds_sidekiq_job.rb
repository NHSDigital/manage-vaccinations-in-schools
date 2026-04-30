# frozen_string_literal: true

class PatientUpdateFromPDSSidekiqJob < ApplicationJobSidekiq
  include PDSThrottlingConcern

  sidekiq_options queue: :pds

  def perform(patient_id, search_results)
    patient = Patient.find(patient_id)
    search_results ||= []
    PatientUpdateFromPDSJob.new.perform(patient, search_results)
  end
end
