# frozen_string_literal: true

describe Careplus::AutomatedReportSender do
  subject(:call) { described_class.call(team_id: team.id) }

  let(:team) do
    create(:team, :with_careplus_enabled, programmes: Programme.all)
  end
  let(:programme) { Programme.hpv }
  let(:session) { create(:session, team:, programmes: [programme]) }
  let(:endpoint) do
    "#{Settings.careplus.base_url}/#{team.careplus_namespace}/soap.SchImms.cls"
  end
  let(:response_status) { 200 }
  let(:response_body) { "<result>OK</result>" }
  let(:yesterday) { Date.new(2025, 8, 31) }
  let(:yesterday_academic_year) { yesterday.academic_year }

  before do
    stub_request(:post, endpoint).to_return(
      status: response_status,
      body: response_body
    )
  end

  around { |example| travel_to(Date.new(2025, 9, 1)) { example.run } }

  it "creates, sends, and stores a sent report with linked vaccination records" do
    record =
      create(
        :vaccination_record,
        session:,
        programme:,
        performed_at: yesterday,
        created_at: yesterday,
        updated_at: yesterday
      )

    expect { call }.to change(CareplusReport, :count).by(1).and(
      change(CareplusReportVaccinationRecord, :count).by(1)
    )

    report = CareplusReport.last

    expect(report).to have_attributes(
      team:,
      academic_year: yesterday_academic_year,
      date_from: yesterday,
      date_to: yesterday,
      status: "sent"
    )
    expect(report.sent_at).to be_present
    expect(report.vaccination_records).to contain_exactly(record)
    expect(WebMock).to have_requested(:post, endpoint).once
  end

  it "uses yesterday and its academic year for the automated export scope" do
    create(
      :vaccination_record,
      session:,
      programme:,
      performed_at: yesterday,
      created_at: yesterday,
      updated_at: yesterday
    )

    expect(Reports::AutomatedCareplusExporter).to receive(
      :vaccination_records_scope
    ).with(
      team:,
      academic_year: yesterday_academic_year,
      start_date: yesterday,
      end_date: yesterday
    ).and_call_original

    call
  end

  it "splits yesterday's scope into batches of 10000 records" do
    stub_const("#{described_class}::BATCH_SIZE", 2)
    records =
      Array.new(3) do
        create(
          :vaccination_record,
          session:,
          programme:,
          performed_at: yesterday,
          created_at: yesterday,
          updated_at: yesterday
        )
      end

    expect { call }.to change(CareplusReport, :count).by(2).and(
      change(CareplusReportVaccinationRecord, :count).by(3)
    )

    expect(WebMock).to have_requested(:post, endpoint).twice
    expect(
      CareplusReport
        .order(:id)
        .map { |report| report.vaccination_records.count }
    ).to eq([2, 1])
    expect(
      CareplusReport
        .joins(:vaccination_records)
        .distinct
        .flat_map(&:vaccination_records)
    ).to match_array(records)
  end

  context "when CarePlus returns a failure response" do
    let(:response_status) { 500 }
    let(:response_body) { "<fault>Error</fault>" }

    it "marks the report as failed, keeps linked vaccination records, and raises for retry" do
      record =
        create(
          :vaccination_record,
          session:,
          programme:,
          performed_at: yesterday,
          created_at: yesterday,
          updated_at: yesterday
        )

      expect { call }.to raise_error(
        described_class::FailedResponseError,
        "CarePlus request failed with HTTP 500: "
      ).and change(CareplusReport, :count).by(1).and(
              change(CareplusReportVaccinationRecord, :count).by(1)
            )

      report = CareplusReport.last
      expect(report).to have_attributes(status: "failed", sent_at: nil)
      expect(report.vaccination_records).to contain_exactly(record)
    end
  end

  context "when CarePlus raises an error" do
    before { stub_request(:post, endpoint).to_raise(Timeout::Error) }

    it "marks the report as failed and keeps linked vaccination records before re-raising" do
      record =
        create(
          :vaccination_record,
          session:,
          programme:,
          performed_at: yesterday,
          created_at: yesterday,
          updated_at: yesterday
        )

      expect { call }.to raise_error(Timeout::Error)

      report = CareplusReport.last
      expect(report).to have_attributes(status: "failed", sent_at: nil)
      expect(report.vaccination_records).to contain_exactly(record)
    end
  end

  context "when the team is no longer eligible for automated reports" do
    before { team.update!(careplus_username: nil) }

    it "does nothing" do
      expect { call }.not_to change(CareplusReport, :count)
    end
  end
end
