# frozen_string_literal: true

describe RemoveExportFileDataJob do
  subject(:job) { described_class.new }

  describe "#perform" do
    context "when there are exports older than retention period" do
      let!(:old_export) do
        create(:export).tap do |export|
          export.update_columns(
            created_at: 200.hours.ago,
            file_data: "file data",
            status: "ready"
          )
        end
      end

      it "clears file_data and marks the export as expired" do
        job.perform

        old_export.reload
        expect(old_export).to be_expired
        expect(old_export.file_data).to be_nil
      end
    end

    context "when there are recent exports within retention period" do
      let!(:recent_export) { create(:export) }

      it "does not expire recent exports" do
        job.perform

        recent_export.reload
        expect(recent_export).to be_pending
      end
    end

    context "when an export is already expired" do
      before do
        create(:export).tap do |export|
          export.update_columns(created_at: 200.hours.ago, status: "expired")
        end
      end

      it "does not raise" do
        expect { job.perform }.not_to raise_error
      end
    end
  end
end
