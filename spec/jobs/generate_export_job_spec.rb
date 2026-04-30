# frozen_string_literal: true

describe GenerateExportJob do
  subject(:job) { described_class.new }

  let(:export) { create(:export) }

  describe "#perform" do
    before do
      allow(export.exportable).to receive(:generate_file).and_return("csv,data")
    end

    it "generates file, attaches to export, and updates status" do
      job.perform(export)

      export.reload
      expect(export).to be_ready
      expect(export.file_data).to be_present
    end

    context "when export is already ready" do
      before { export.ready! }

      it("does not overwrite") do
        expect { job.perform(export) }.not_to change(export, :updated_at)
      end
    end

    context "when exporter raises" do
      before do
        allow(export.exportable).to receive(:generate_file).and_raise(
          StandardError
        )
      end

      it "sets status to failed" do
        job.perform(export)

        export.reload
        expect(export).to be_failed
      end
    end
  end
end
