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

  private_class_method :new
end
