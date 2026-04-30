# frozen_string_literal: true

class UpdatePatientsFromPDS
  def initialize(patients, queue:)
    @patients = patients
    @queue = queue
  end

  def call
    return unless enqueue?

    patients.find_each do |patient|
      if patient.nhs_number.nil?
        PDSCascadingSearchSidekiqJob.set(queue:).perform_async(
          patient.to_global_id.to_s,
          nil,
          nil,
          nil
        )
      else
        PatientUpdateFromPDSSidekiqJob.set(queue:).perform_async(
          patient.id,
          nil
        )
      end
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :patients, :queue

  def enqueue?
    Flipper.enabled?(:pds) && Flipper.enabled?(:pds_enqueue_bulk_updates)
  end
end
