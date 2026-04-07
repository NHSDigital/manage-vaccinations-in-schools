# frozen_string_literal: true

describe SendCareplusExportJob do
  subject(:perform_now) { described_class.perform_now(team.id) }

  let(:team) { create(:team, :with_careplus_enabled) }
  let(:csv) { "NHS Number,Surname\n1234567890,Smith\n" }

  before do
    allow(Reports::AutomatedCareplusExporter).to receive(:call).and_return(csv)
    allow(Reports::CareplusSoapSender).to receive(:call)
  end

  it "exports today's records and sends them to CarePlus" do
    travel_to Date.new(2026, 4, 7) do
      perform_now
    end

    expect(Reports::AutomatedCareplusExporter).to have_received(:call).with(
      team:,
      academic_year: AcademicYear.current,
      start_date: Date.new(2026, 4, 7),
      end_date: Date.new(2026, 4, 7)
    )
    expect(Reports::CareplusSoapSender).to have_received(:call).with(
      csv_payload: csv,
      username: team.careplus_username,
      password: team.careplus_password,
      namespace: team.careplus_namespace
    )
  end

  context "when the team no longer has careplus enabled at execution time" do
    before { team.update!(careplus_staff_code: nil) }

    it "skips the export without raising" do
      expect { perform_now }.not_to raise_error
      expect(Reports::AutomatedCareplusExporter).not_to have_received(:call)
    end
  end

  context "when the team loses credentials between enqueue and execution" do
    before { team.update!(careplus_username: nil) }

    it "skips the export without raising" do
      expect { perform_now }.not_to raise_error
      expect(Reports::AutomatedCareplusExporter).not_to have_received(:call)
    end
  end

  context "when the team loses its namespace between enqueue and execution" do
    before { team.update!(careplus_namespace: nil) }

    it "skips the export without raising" do
      expect { perform_now }.not_to raise_error
      expect(Reports::AutomatedCareplusExporter).not_to have_received(:call)
    end
  end

  context "when the CarePlus server returns a 5xx error" do
    before do
      allow(Reports::CareplusSoapSender).to receive(:call).and_raise(
        Reports::CareplusSoapSender::ServerError.new(
          instance_double(
            Net::HTTPServiceUnavailable,
            code: "503",
            message: "Service Unavailable"
          )
        )
      )
    end

    it "re-enqueues the job for retry" do
      expect { perform_now }.to have_enqueued_job(described_class)
    end
  end

  context "when a network timeout occurs" do
    before do
      allow(Reports::CareplusSoapSender).to receive(:call).and_raise(
        Net::ReadTimeout
      )
    end

    it "re-enqueues the job for retry" do
      expect { perform_now }.to have_enqueued_job(described_class)
    end
  end
end
