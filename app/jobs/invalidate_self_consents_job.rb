# frozen_string_literal: true

class InvalidateSelfConsentsJob < ApplicationJobSidekiq
  sidekiq_options queue: :consents

  def perform
    programmes = Programme.all
    academic_year = AcademicYear.current

    programmes.each do |programme|
      patients = Patient.has_programme_status("due", programme:, academic_year:)

      Team.find_each do |team|
        consents =
          Consent
            .via_self_consent
            .for_programme(programme)
            .where(academic_year:, team:, patient: patients)
            .where("created_at < ?", Date.current.beginning_of_day)
            .not_withdrawn

        triages =
          Triage
            .for_programme(programme)
            .where(
              academic_year:,
              team:,
              patient_id: consents.pluck(:patient_id)
            )
            .where("created_at < ?", Date.current.beginning_of_day)

        ActiveRecord::Base.transaction do
          consents.invalidate_all
          triages.safe_to_invalidate_automatically.invalidate_all
        end
      end
    end
  end
end
