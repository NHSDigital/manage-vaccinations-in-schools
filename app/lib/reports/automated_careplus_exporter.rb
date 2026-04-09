# frozen_string_literal: true

class Reports::AutomatedCareplusExporter
  VACCINE_COLUMNS = %i[
    vaccine
    dose
    reason_not_given
    site
    manufacturer
    batch_number
  ].freeze

  def self.call(team:, academic_year:, start_date:, end_date:)
    Reports::CareplusExporter.call(
      **shared_args(team:, academic_year:),
      start_date:,
      end_date:,
      include_missing_nhs_number: false
    )
  end

  def self.from_records(vaccination_records:, team:, academic_year:)
    Reports::CareplusExporter.from_records(
      **shared_args(team:, academic_year:),
      vaccination_records:
        vaccination_records.includes(
          :patient,
          :vaccine,
          session: %i[location team_location]
        )
    )
  end

  def self.vaccination_records_scope(
    team:,
    academic_year:,
    start_date:,
    end_date:
  )
    Reports::CareplusExporter.vaccination_records_scope(
      team:,
      programmes: team.programmes,
      academic_year:,
      start_date:,
      end_date:,
      include_missing_nhs_number: false
    )
  end

  def self.shared_args(team:, academic_year:)
    {
      team:,
      programmes: team.programmes,
      academic_year:,
      include_gender: false,
      vaccine_columns: VACCINE_COLUMNS
    }
  end

  private_class_method :new, :shared_args
end
