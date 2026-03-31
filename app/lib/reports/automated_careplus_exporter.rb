# frozen_string_literal: true

class Reports::AutomatedCareplusExporter
  def self.call(team:, academic_year:, start_date:, end_date:)
    Reports::CareplusExporter.call(
      team:,
      programmes: team.programmes,
      academic_year:,
      start_date:,
      end_date:,
      include_gender: false,
      include_missing_nhs_number: false,
      vaccine_columns: %i[
        vaccine
        dose
        reason_not_given
        site
        manufacturer
        batch_number
      ]
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

  private_class_method :new
end
