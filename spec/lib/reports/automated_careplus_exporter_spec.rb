# frozen_string_literal: true

describe Reports::AutomatedCareplusExporter do
  it "passes the correct parameters to CareplusExporter" do
    team = create(:team)
    academic_year = AcademicYear.current
    start_date = 1.month.ago.to_date
    end_date = Date.current

    expect(Reports::CareplusExporter).to receive(:call).with(
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

    described_class.call(team:, academic_year:, start_date:, end_date:)
  end
end
