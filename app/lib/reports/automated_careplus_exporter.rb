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
    base_scope =
      Reports::CareplusExporter.vaccination_records_scope(
        team:,
        programmes: team.programmes,
        academic_year:,
        start_date: nil,
        end_date: nil,
        include_missing_nhs_number: false
      )
    date_range_scope =
      base_scope.created_or_updated_between(start_date, end_date)

    return date_range_scope if team.careplus_automated_reports_enabled_at.blank?

    nhs_number_first_added_scope =
      base_scope
        .created_or_updated_on_or_after(
          team.careplus_automated_reports_enabled_at
        )
        .where.not(patients: { nhs_number_first_added_at: nil })

    if start_date.present?
      nhs_number_first_added_scope =
        nhs_number_first_added_scope.where(
          "patients.nhs_number_first_added_at >= ?",
          start_date.beginning_of_day
        )
    end

    if end_date.present?
      nhs_number_first_added_scope =
        nhs_number_first_added_scope.where(
          "patients.nhs_number_first_added_at <= ?",
          end_date.end_of_day
        )
    end

    date_range_scope.or(nhs_number_first_added_scope).distinct
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
