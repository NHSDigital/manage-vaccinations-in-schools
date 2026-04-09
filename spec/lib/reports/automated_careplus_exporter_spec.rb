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

    described_class.call(team:, academic_year:, start_date:, end_date:)
  end

  it "delegates vaccination_records_scope to CareplusExporter with the correct parameters" do
    team = create(:team)
    academic_year = AcademicYear.current
    start_date = 1.month.ago.to_date
    end_date = Date.current

    expect(Reports::CareplusExporter).to receive(
      :vaccination_records_scope
    ).with(
      team:,
      programmes: team.programmes,
      academic_year:,
      start_date:,
      end_date:,
      include_missing_nhs_number: false
    )

    described_class.vaccination_records_scope(
      team:,
      academic_year:,
      start_date:,
      end_date:
    )
  end

  it "passes the correct parameters to CareplusExporter.from_records" do
    team = create(:team)
    academic_year = AcademicYear.current
    vaccination_records = instance_double(ActiveRecord::Relation)
    eager_loaded = instance_double(ActiveRecord::Relation)
    allow(vaccination_records).to receive(:includes).with(
      :patient,
      :vaccine,
      session: %i[location team_location]
    ).and_return(eager_loaded)

    expect(Reports::CareplusExporter).to receive(:from_records).with(
      vaccination_records: eager_loaded,
      team:,
      programmes: team.programmes,
      academic_year:,
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

    described_class.from_records(vaccination_records:, team:, academic_year:)
  end
end
