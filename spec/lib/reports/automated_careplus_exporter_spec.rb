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

  describe ".vaccination_records_scope" do
    let(:programme) { Programme.hpv }
    let(:export_date) { Date.new(2025, 8, 31) }
    let(:team) do
      create(
        :team,
        :with_careplus_enabled,
        programmes: [programme],
        careplus_automated_reports_enabled_at: Time.zone.local(2025, 8, 28, 10)
      )
    end
    let(:session) { create(:session, team:, programmes: [programme]) }

    it "includes records changed in the export window" do
      included_record =
        create(
          :vaccination_record,
          patient: create(:patient, session:),
          session:,
          programme:,
          performed_at: export_date,
          created_at: export_date,
          updated_at: export_date
        )

      scope =
        described_class.vaccination_records_scope(
          team:,
          academic_year: export_date.academic_year,
          start_date: export_date,
          end_date: export_date
        )

      expect(scope).to include(included_record)
    end

    it "includes older records for patients who first had an NHS number added in the export window" do
      patient =
        create(
          :patient,
          session:,
          nhs_number_first_added_at: Time.zone.local(2025, 8, 31, 9)
        )
      included_record =
        create(
          :vaccination_record,
          patient:,
          session:,
          programme:,
          performed_at: Date.new(2025, 8, 29),
          created_at: Time.zone.local(2025, 8, 29, 12),
          updated_at: Time.zone.local(2025, 8, 29, 12)
        )

      scope =
        described_class.vaccination_records_scope(
          team:,
          academic_year: export_date.academic_year,
          start_date: export_date,
          end_date: export_date
        )

      expect(scope).to include(included_record)
    end
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
