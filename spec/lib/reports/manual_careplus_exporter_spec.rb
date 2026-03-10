# frozen_string_literal: true

describe Reports::ManualCareplusExporter do
  it "passes the correct parameters to CareplusExporter" do
    team = build_stubbed(:team)
    programme = Programme.hpv
    academic_year = AcademicYear.current
    start_date = 1.month.ago.to_date
    end_date = Date.current

    expect(Reports::CareplusExporter).to receive(:call).with(
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

    described_class.call(
      team:,
      programme:,
      academic_year:,
      start_date:,
      end_date:
    )
  end
end
