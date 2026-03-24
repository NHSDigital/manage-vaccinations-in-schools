# frozen_string_literal: true

# == Schema Information
#
# Table name: immunisation_imports
#
#  id                           :bigint           not null, primary key
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text             not null
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  ignored_record_count         :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  type                         :integer          not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_immunisation_imports_on_team_id              (team_id)
#  index_immunisation_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#

describe ImmunisationImport do
  subject(:immunisation_import) do
    create(:immunisation_import, team:, csv:, uploaded_by:)
  end

  before do
    create(:school, urn: "110158", systm_one_code: "TT110158")
    create(:school, urn: "120026")
    create(:school, urn: "144012")
    create(:school, urn: "100000")
  end

  let(:programmes) { [Programme.flu] }
  let(:team) do
    if type == "national_reporting"
      create(:team, :national_reporting)
    else
      create(:team, ods_code: "R1L", programmes:)
    end
  end
  let(:school) { create(:school, urn: "123456") }

  let(:file) { "valid_flu.csv" }
  let(:csv) { fixture_file_upload("immunisation_import/#{type}/#{file}") }
  let(:uploaded_by) { create(:user, team:) }

  let(:type) { "point_of_care" }

  it_behaves_like "a CSVImportable model"

  describe "#load_data!" do
    before { immunisation_import.load_data! }

    context "with malformed CSV" do
      let(:file) { "malformed.csv" }

      it "is invalid" do
        expect(immunisation_import).to be_invalid
        expect(immunisation_import.errors[:csv]).to include(/correct format/)
      end
    end

    context "with empty CSV" do
      let(:file) { "empty.csv" }

      it "is invalid" do
        expect(immunisation_import).to be_invalid
        expect(immunisation_import.errors[:csv]).to include(/one record/)
      end
    end

    context "with too many rows" do
      let(:file) { "valid_flu.csv" }

      before { stub_const("CSVImportable::MAX_CSV_ROWS", 2) }

      it "is invalid" do
        expect(immunisation_import).to be_invalid
        expect(immunisation_import.errors[:csv]).to include(/less than 2 rows/)
      end
    end

    context "with a duplicated row" do
      let(:file) { "duplicate_row.csv" }

      before { immunisation_import.parse_rows! }

      shared_examples "duplicate row" do
        it "is invalid" do
          expect(immunisation_import).to be_invalid
          expect(immunisation_import.rows.first.errors[:base]).to include(
            /The record on this row appears to be a duplicate of row 3\./
          )
          expect(immunisation_import.rows.second.errors[:base]).to include(
            /The record on this row appears to be a duplicate of row 2\./
          )
        end
      end

      context "with a point of care import" do
        let(:type) { "point_of_care" }

        it_behaves_like "duplicate row"
      end

      context "with a national reporting import" do
        let(:type) { "national_reporting" }

        it_behaves_like "duplicate row"
      end
    end
  end

  describe "#parse_rows!" do
    before { immunisation_import.parse_rows! }

    around { |example| travel_to(test_date) { example.run } }

    let(:test_date) { Date.new(2025, 8, 1) }

    context "with valid flu rows" do
      let(:programmes) { [Programme.flu] }
      let(:file) { "valid_flu.csv" }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with valid HPV rows" do
      let(:programmes) { [Programme.hpv] }
      let(:file) { "valid_hpv.csv" }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with valid MMR rows" do
      let(:programmes) { [Programme.mmr] }
      let(:file) { "valid_mmr.csv" }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with valid hpv rows, and an instruction row" do
      let(:programmes) { [Programme.hpv] }
      let(:file) { "valid_hpv_with_instruction_row.csv" }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with a SystmOne file" do
      let(:programmes) { [Programme.hpv, Programme.menacwy, Programme.flu] }
      let(:file) { "systm_one.csv" }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with a national reporting upload" do
      let(:type) { "national_reporting" }
      let(:file) { "valid_mixed_flu_hpv.csv" }

      let(:test_date) { Date.new(2025, 12, 1) }

      it "populates the rows" do
        expect(immunisation_import).to be_valid
        expect(immunisation_import.rows).not_to be_empty
      end
    end

    context "with invalid rows" do
      let(:file) { "invalid_rows.csv" }

      it "is invalid" do
        expect(immunisation_import).to be_invalid
        expect(immunisation_import.errors).not_to include(:row_1) # Header row
        expect(immunisation_import.errors).not_to include(:row_2) # Instruction row
        expect(immunisation_import.errors).to include(:row_3, :row_4)
      end
    end
  end

  describe "#process!" do
    subject(:process!) { immunisation_import.process! }

    around { |example| travel_to(Date.new(2025, 8, 1)) { example.run } }

    context "with an empty CSV file (no data rows)" do
      let(:programmes) { [Programme.flu] }
      let(:file) { "valid_flu.csv" }

      it "handles empty imports without raising NoMethodError" do
        # rubocop:disable RSpec/SubjectStub
        allow(immunisation_import).to receive(:process_row).and_return(
          :ignored_record_count
        )
        # rubocop:enable RSpec/SubjectStub

        expect { process! }.not_to raise_error
      end
    end

    context "with valid flu rows" do
      let(:programmes) { [Programme.flu] }
      let(:file) { "valid_flu.csv" }

      it "creates locations, patients, and vaccination records" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :processed_at).from(nil)
          .and change(immunisation_import.vaccination_records, :count).by(11)
          .and change(immunisation_import.patients, :count).by(11)
          .and not_change(immunisation_import.patient_locations, :count)

        # Second import should not duplicate the vaccination records if they're
        # identical.

        # stree-ignore
        expect { immunisation_import.process! }
          .to not_change(immunisation_import, :processed_at)
          .and not_change(VaccinationRecord, :count)
          .and not_change(Patient, :count)
          .and not_change(PatientLocation, :count)
      end

      it "links the correct objects with each other" do
        process!

        expect(VaccinationRecord.all.map(&:patient)).to match_array(Patient.all)

        expect(immunisation_import.vaccination_records).to match_array(
          VaccinationRecord.all
        )
        expect(immunisation_import.patients).to match_array(Patient.all)
      end

      it "stores statistics on the import" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :exact_duplicate_record_count).to(0)
          .and change(immunisation_import, :new_record_count).to(11)
      end

      it "ignores and counts duplicate records" do
        create(:immunisation_import, csv:, team:, uploaded_by:).process!
        csv.rewind

        process!
        expect(immunisation_import.exact_duplicate_record_count).to eq(11)
      end

      it "enqueues jobs to look up missing NHS numbers" do
        expect { process! }.to have_enqueued_job(
          PDSCascadingSearchJob
        ).once.on_queue(:imports)
      end

      it "enqueues jobs to update from PDS" do
        expect { process! }.to have_enqueued_job(PatientUpdateFromPDSJob)
          .exactly(10)
          .times
          .on_queue(:imports)
      end
    end

    context "with valid HPV rows" do
      let(:programmes) { [Programme.hpv] }
      let(:file) { "valid_hpv.csv" }

      it "creates locations, patients, and vaccination records" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :processed_at).from(nil)
          .and change(immunisation_import.vaccination_records, :count).by(11)
          .and change(immunisation_import.patients, :count).by(10)
          .and not_change(immunisation_import.patient_locations, :count)

        # Second import should not duplicate the vaccination records if they're
        # identical.

        # stree-ignore
        expect { immunisation_import.process! }
          .to not_change(immunisation_import, :processed_at)
          .and not_change(VaccinationRecord, :count)
          .and not_change(Patient, :count)
          .and not_change(PatientLocation, :count)
      end

      it "stores statistics on the import" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :exact_duplicate_record_count).to(0)
          .and change(immunisation_import, :new_record_count).to(11)
      end

      it "ignores and counts duplicate records" do
        create(:immunisation_import, csv:, team:, uploaded_by:).process!
        csv.rewind

        process!
        expect(immunisation_import.exact_duplicate_record_count).to eq(11)
      end

      it "enqueues jobs to look up missing NHS numbers" do
        expect { process! }.to have_enqueued_job(
          PDSCascadingSearchJob
        ).once.on_queue(:imports)
      end

      it "enqueues jobs to update from PDS" do
        expect { process! }.to have_enqueued_job(PatientUpdateFromPDSJob)
          .exactly(9)
          .times
          .on_queue(:imports)
      end
    end

    context "with valid MMR rows" do
      let(:programmes) { [Programme.mmr] }
      let(:file) { "valid_mmr.csv" }

      it "creates locations, patients, and vaccination records" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :processed_at).from(nil)
          .and change(immunisation_import.vaccination_records, :count).by(11)
          .and change(immunisation_import.patients, :count).by(10)
          .and not_change(immunisation_import.patient_locations, :count)

        # Second import should not duplicate the vaccination records if they're
        # identical.

        # stree-ignore
        expect { immunisation_import.process! }
          .to not_change(immunisation_import, :processed_at)
          .and not_change(VaccinationRecord, :count)
          .and not_change(Patient, :count)
          .and not_change(PatientLocation, :count)
      end

      it "stores statistics on the import" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :exact_duplicate_record_count).to(0)
          .and change(immunisation_import, :new_record_count).to(11)
      end

      it "ignores and counts duplicate records" do
        create(:immunisation_import, csv:, team:, uploaded_by:).process!
        csv.rewind

        process!
        expect(immunisation_import.exact_duplicate_record_count).to eq(11)
      end

      it "enqueues jobs to look up missing NHS numbers" do
        expect { process! }.to have_enqueued_job(
          PDSCascadingSearchJob
        ).once.on_queue(:imports)
      end

      it "enqueues jobs to update from PDS" do
        expect { process! }.to have_enqueued_job(PatientUpdateFromPDSJob)
          .exactly(9)
          .times
          .on_queue(:imports)
      end
    end

    context "with a SystmOne file format" do
      let(:programmes) { [Programme.hpv, Programme.menacwy, Programme.flu] }
      let(:file) { "systm_one.csv" }

      it "creates locations, patients, and vaccination records" do
        # stree-ignore
        expect { process! }
          .to change(immunisation_import, :processed_at).from(nil)
          .and change(immunisation_import.vaccination_records, :count).by(4)
          .and change(immunisation_import.patients, :count).by(4)
          .and not_change(immunisation_import.patient_locations, :count)

        # Second import should not duplicate the vaccination records if they're
        # identical.

        # stree-ignore
        expect { immunisation_import.process! }
          .to not_change(immunisation_import, :processed_at)
          .and not_change(VaccinationRecord, :count)
          .and not_change(Patient, :count)
          .and not_change(PatientLocation, :count)
      end
    end

    context "with an existing patient matching the name" do
      let(:programmes) { [Programme.flu] }
      let(:file) { "valid_flu.csv" }

      let!(:patient) do
        create(
          :patient,
          given_name: "Chyna",
          family_name: "Pickle",
          date_of_birth: Date.new(2012, 9, 12),
          address_postcode: "LE3 2DA",
          nhs_number: nil
        )
      end

      it "doesn't create an additional patient" do
        expect { process! }.to change(Patient, :count).by(10)
      end

      it "doesn't update the NHS number on the existing patient" do
        expect { process! }.not_to change(patient, :nhs_number).from(nil)
      end
    end

    context "with an existing patient matching the name but with a different case" do
      let(:programmes) { [Programme.flu] }
      let(:file) { "valid_flu.csv" }

      before do
        create(
          :patient,
          given_name: "chyna",
          family_name: "PICKLE",
          date_of_birth: Date.new(2012, 9, 12),
          address_postcode: "LE3 2DA",
          nhs_number: nil
        )
      end

      it "doesn't create an additional patient" do
        expect { process! }.to change(Patient, :count).by(10)
      end
    end

    context "with a patient record that has different attributes" do
      let(:programmes) { [Programme.hpv] }
      let(:file) { "valid_hpv_with_changes.csv" }
      let!(:existing_patient) do
        create(
          :patient,
          nhs_number: "7420180008",
          given_name: "Chyna",
          family_name: "Pickle",
          date_of_birth: Date.new(2011, 9, 12),
          gender_code: "not_specified",
          address_postcode: "LE3 2DA"
        )
      end

      it "ignores changes in the patient record" do
        expect { process! }.not_to change(Patient, :count)
        expect(existing_patient.reload.pending_changes).to be_empty
      end
    end

    context "with the same patient record within the upload" do
      let(:programmes) { [Programme.flu, Programme.hpv] }
      let(:file) { "valid_duplicate_patient.csv" }

      it "only creates one patient record" do
        expect { process! }.to change(Patient, :count).by(1)
      end

      it "links both vaccination records to the same patient" do
        process!
        patients =
          immunisation_import
            .vaccination_records
            .includes(:patient)
            .map(&:patient)
        expect(patients).to all(eq(Patient.first))
      end
    end

    context "with the same patient record within the upload and no NHS number" do
      let(:programmes) { [Programme.flu, Programme.hpv] }
      let(:file) { "valid_duplicate_patient_no_nhs_number.csv" }

      it "only creates one patient record" do
        expect { process! }.to change(Patient, :count).by(1)
      end

      it "links both vaccination records to the same patient" do
        process!
        patients =
          immunisation_import
            .vaccination_records
            .includes(:patient)
            .map(&:patient)
        expect(patients).to all(eq(Patient.first))
      end
    end
  end

  describe "#post_commit!" do
    subject(:post_commit!) { immunisation_import.send(:post_commit!) }

    let(:immunisation_import) do
      create(
        :immunisation_import,
        team:,
        vaccination_records: [vaccination_record]
      )
    end
    let(:session) { create(:session, location: school, programmes:) }
    let(:vaccination_record) do
      create(:vaccination_record, programme: programmes.first, session:)
    end

    before { Flipper.enable(:imms_api_sync_job) }

    it "syncs the flu vaccination record to the NHS Immunisations API" do
      expect { post_commit! }.to enqueue_sidekiq_job(
        SyncVaccinationRecordToNHSJob
      ).with(vaccination_record.id).once.on("immunisations_api_sync")
    end
  end

  describe "#postprocess_rows!" do
    subject(:postprocess_rows!) { immunisation_import.send(:postprocess_rows!) }

    let(:immunisation_import) do
      create(
        :immunisation_import,
        team:,
        vaccination_records: [vaccination_record]
      )
    end

    let(:session) { create(:session, location: school, programmes:) }
    let(:vaccination_record) do
      create(:vaccination_record, programme: programmes.first, session:)
    end

    context "for the HPV programme" do
      let(:programmes) { [Programme.hpv] }

      it "doesn't create a next dose triage" do
        expect { postprocess_rows! }.not_to change(Triage, :count)
      end
    end

    context "for the MMR programme" do
      let(:programmes) { [Programme.mmr] }

      it "creates a next dose triage" do
        expect { postprocess_rows! }.to change(Triage, :count).by(1)
      end
    end

    it "calls the AlreadyHadNotificationSender for the vaccination record" do
      expect(AlreadyHadNotificationSender).to receive(:call).with(
        vaccination_record:
      )

      postprocess_rows!
    end
  end
end
