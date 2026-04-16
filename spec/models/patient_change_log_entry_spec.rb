# frozen_string_literal: true

describe PatientChangeLogEntry do
  describe "associations" do
    it { should belong_to(:patient) }
    it { should belong_to(:user).optional }
  end

  describe ".log_saved_changes!" do
    subject(:log_changes) do
      described_class.log_saved_changes!(patient:, user:, source: :manual_edit)
    end

    let(:patient) { create(:patient, given_name: "John") }
    let(:user) { create(:user) }

    context "when a tracked attribute changed" do
      before { patient.update!(given_name: "Jonathan") }

      it "creates a log entry" do
        expect { log_changes }.to change(described_class, :count).by(1)
      end

      it "records the correct attributes" do
        log_changes
        entry = described_class.last
        expect(entry.patient).to eq(patient)
        expect(entry.user).to eq(user)
        expect(entry.source).to eq("manual_edit")
        expect(entry.recorded_changes["given_name"]).to eq(%w[John Jonathan])
      end
    end

    context "when no tracked attributes changed" do
      before { patient.reload }

      it "does not create a log entry" do
        expect { log_changes }.not_to change(described_class, :count)
      end
    end
  end

  describe ".log_import_changes!" do
    subject(:log_changes) do
      described_class.log_import_changes!(patients: [patient], import:)
    end

    let(:uploader) { create(:user) }
    let(:import) { create(:cohort_import, uploaded_by: uploader) }

    context "with an existing patient whose tracked attributes changed" do
      let(:patient) { create(:patient, family_name: "Smith") }

      before { patient.family_name = "Jones" }

      it "creates a log entry" do
        expect { log_changes }.to change(described_class, :count).by(1)
      end

      it "records the correct source and user" do
        log_changes
        entry = described_class.last
        expect(entry.source).to eq("cohort_import")
        expect(entry.user).to eq(uploader)
        expect(entry.recorded_changes["family_name"]).to eq(%w[Smith Jones])
      end
    end

    context "with a new (unpersisted) patient" do
      let(:patient) { build(:patient, given_name: "New") }

      it "does not create a log entry" do
        expect { log_changes }.not_to change(described_class, :count)
      end
    end

    context "with a patient whose changes are not tracked attributes" do
      let(:patient) { create(:patient) }

      it "does not create a log entry" do
        expect { log_changes }.not_to change(described_class, :count)
      end
    end

    context "with a class import" do
      let(:import) { create(:class_import, uploaded_by: uploader) }
      let(:patient) { create(:patient, family_name: "Smith") }

      before { patient.family_name = "Jones" }

      it "sets source to class_import" do
        log_changes
        expect(described_class.last.source).to eq("class_import")
      end
    end
  end
end
