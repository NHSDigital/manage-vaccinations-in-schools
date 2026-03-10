# frozen_string_literal: true

class Reports::ManualCareplusExporter
  def self.call(team:, programme:, academic_year:, start_date:, end_date:)
    Reports::CareplusExporter.call(
      team:,
      programmes: [programme],
      academic_year:,
      start_date:,
      end_date:,
      include_gender: true,
      vaccine_columns: %i[
        vaccine
        vaccine_code
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
