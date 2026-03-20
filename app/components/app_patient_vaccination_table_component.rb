# frozen_string_literal: true

class AppPatientVaccinationTableComponent < ViewComponent::Base
  def initialize(
    patient,
    academic_year:,
    programme: nil,
    show_caption: false,
    show_details: true
  )
    @patient = patient
    @academic_year = academic_year
    @programme = programme
    @show_caption = show_caption
    @show_details = show_details
  end

  private

  delegate :govuk_table, :vaccination_record_source, to: :helpers

  attr_reader :patient, :academic_year, :programme, :show_caption, :show_details

  def show_programme = programme.nil?

  def vaccination_records
    patient
      .vaccination_records
      .then { programme ? it.for_programme(programme) : it }
      .includes(:location)
      .order_by_performed_at
      .select { it.show_in_academic_year?(academic_year) }
  end
end
