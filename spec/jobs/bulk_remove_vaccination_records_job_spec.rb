# frozen_string_literal: true

describe BulkRemoveVaccinationRecordsJob do
  include ActiveJob::TestHelper

  subject(:perform_job) do
    described_class.new.perform(import.id, import.vaccination_record_ids)
  end

  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:user) { create(:user, team:) }
  let(:import) { create(:immunisation_import, team:, uploaded_by: user) }

  def add_vr_to_import(imp = import)
    vr = create(:vaccination_record, programme:)
    imp.vaccination_records << vr
    vr
  end

  describe "#perform" do
    context "when a vaccination record belongs only to this import" do
      before { add_vr_to_import }

      it "destroys the vaccination record" do
        expect { perform_job }.to change(VaccinationRecord, :count).by(-1)
      end

      it "logs 1 deleted and 0 unlinked" do
        expect(Rails.logger).to receive(:info).with(
          "Deleted 1 vaccination records and unlinked 0 shared records from immunisation import #{import.id}"
        )
        perform_job
      end
    end

    context "when a vaccination record belongs to multiple imports" do
      let!(:vr) { add_vr_to_import }
      let!(:other_import) do
        create(:immunisation_import, team:, uploaded_by: user)
      end

      before { other_import.vaccination_records << vr }

      it "does not destroy the vaccination record" do
        expect { perform_job }.not_to change(VaccinationRecord, :count)
      end

      it "removes the link between this import and the record" do
        expect { perform_job }.to change {
          import.vaccination_records.reload.count
        }.by(-1)
      end

      it "keeps the record linked to the other import" do
        perform_job
        expect(other_import.vaccination_records.reload).to include(vr)
      end

      it "logs 0 deleted and 1 unlinked" do
        expect(Rails.logger).to receive(:info).with(
          "Deleted 0 vaccination records and unlinked 1 shared records from immunisation import #{import.id}"
        )
        perform_job
      end
    end

    context "with a mix of exclusive and shared records" do
      let!(:exclusive_vr) { add_vr_to_import }
      let!(:shared_vr) { add_vr_to_import }
      let!(:other_import) do
        create(:immunisation_import, team:, uploaded_by: user)
      end

      before { other_import.vaccination_records << shared_vr }

      it "destroys only the exclusive record" do
        expect { perform_job }.to change(VaccinationRecord, :count).by(-1)
        expect { exclusive_vr.reload }.to raise_error(
          ActiveRecord::RecordNotFound
        )
        expect { shared_vr.reload }.not_to raise_error
      end

      it "unlinks the shared record from this import" do
        perform_job
        expect(import.vaccination_records.reload).not_to include(shared_vr)
        expect(other_import.vaccination_records.reload).to include(shared_vr)
      end

      it "logs the correct counts" do
        expect(Rails.logger).to receive(:info).with(
          "Deleted 1 vaccination records and unlinked 1 shared records from immunisation import #{import.id}"
        )
        perform_job
      end
    end

    context "when batch ids do not match any of the import's records" do
      it "logs 0 deleted and 0 unlinked" do
        unrelated_vr = create(:vaccination_record, programme:)
        expect(Rails.logger).to receive(:info).with(
          "Deleted 0 vaccination records and unlinked 0 shared records from immunisation import #{import.id}"
        )
        described_class.new.perform(import.id, [unrelated_vr.id])
      end
    end

    context "after processing" do
      let!(:vr) { add_vr_to_import }

      it "calls PatientTeamUpdater for the affected patients" do
        expect(PatientTeamUpdater).to receive(:call).with(
          patient_scope: Patient.where(id: [vr.patient_id])
        )
        perform_job
      end

      it "calls PatientStatusUpdater for the affected patients" do
        expect(PatientStatusUpdater).to receive(:call).with(
          patient_scope: Patient.where(id: [vr.patient_id])
        )
        perform_job
      end
    end

    context "when all records are removed" do
      before { add_vr_to_import }

      it "sets the import status to processed" do
        perform_job
        expect(import.reload.status).to eq("processed")
      end
    end

    context "when some records remain" do
      let!(:vr) { add_vr_to_import }

      before do
        add_vr_to_import
        described_class.new.perform(import.id, [vr.id])
      end

      it "does not set the import status to processed" do
        expect(import.reload.status).not_to eq("processed")
      end
    end
  end
end
