# frozen_string_literal: true

# == Schema Information
#
# Table name: class_imports
#
#  id                           :bigint           not null, primary key
#  academic_year                :integer          not null
#  changed_record_count         :integer
#  csv_data                     :text
#  csv_filename                 :text
#  csv_removed_at               :datetime
#  exact_duplicate_record_count :integer
#  new_record_count             :integer
#  processed_at                 :datetime
#  reviewed_at                  :datetime         default([]), not null, is an Array
#  reviewed_by_user_ids         :bigint           default([]), not null, is an Array
#  rows_count                   :integer
#  serialized_errors            :jsonb
#  status                       :integer          default("pending_import"), not null
#  year_groups                  :integer          default([]), not null, is an Array
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  location_id                  :bigint           not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_class_imports_on_location_id          (location_id)
#  index_class_imports_on_team_id              (team_id)
#  index_class_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
describe ClassImport do
  subject(:class_import) { create(:class_import, csv:, session:, team:) }

  let(:programmes) { [Programme.hpv] }
  let(:team) { create(:team, programmes:) }
  let(:location) { create(:gias_school, team:) }
  let(:session) { create(:session, location:, programmes:, team:) }

  let(:file) { "valid.csv" }
  let(:csv) { fixture_file_upload("class_import/#{file}") }

  it_behaves_like "a CSVImportable model"

  describe "#load_data!" do
    subject(:load_data!) { class_import.load_data! }

    before { load_data! }

    describe "with malformed CSV" do
      let(:file) { "malformed.csv" }

      it "is invalid" do
        expect(class_import).to be_invalid
        expect(class_import.errors[:csv]).to include(/correct format/)
      end
    end

    describe "with too many rows" do
      let(:file) { "valid.csv" }

      before { stub_const("CSVImportable::MAX_CSV_ROWS", 2) }

      it "is invalid" do
        expect(class_import).to be_invalid
        expect(class_import.errors[:csv]).to include(/less than 2 rows/)
      end
    end
  end

  describe "#parse_rows!" do
    subject(:parse_rows!) { class_import.parse_rows! }

    before { parse_rows! }

    describe "with a BOM" do
      let(:file) { "valid_with_bom.csv" }

      it "removes the BOM" do
        expect(class_import).to be_valid
      end
    end

    describe "with invalid fields" do
      let(:file) { "invalid_fields.csv" }

      it "populates rows" do
        expect(class_import).to be_invalid
        expect(class_import.rows).not_to be_empty
      end
    end

    describe "with unrecognised fields" do
      let(:file) { "valid_extra_fields.csv" }

      it "populates rows" do
        expect(class_import).to be_valid
      end
    end

    describe "with an instruction row, otherwise valid" do
      let(:file) { "valid_instruction_row.csv" }

      it "populates rows" do
        expect(class_import).to be_valid
        expect(class_import.rows.count).to eq(1)
      end
    end

    describe "with an instruction row and an error" do
      let(:file) { "invalid_instruction_row.csv" }

      it "populates rows" do
        expect(class_import).not_to be_valid
        expect(class_import.rows.count).to eq(1)
      end

      it "shows the right error information" do
        expect(class_import.errors.count).to eq(1)
        expect(class_import.errors.to_a[0]).to start_with("Row 3")
      end
    end

    describe "with valid fields" do
      let(:file) { "valid.csv" }

      it "is valid" do
        expect(class_import).to be_valid
      end
    end

    describe "with minimal fields" do
      let(:file) { "valid_minimal.csv" }

      it "is valid" do
        expect(class_import).to be_valid
        expect(class_import.rows.count).to eq(1)
      end
    end

    describe "with minimal fields and an error" do
      let(:file) { "invalid_minimal.csv" }

      it "populates rows" do
        expect(class_import).not_to be_valid
        expect(class_import.rows.count).to eq(1)
      end

      it "shows the right error information" do
        expect(class_import.errors.count).to eq(1)
        expect(class_import.errors.to_a[0]).to start_with("Row 2")
      end
    end
  end

  describe "#process!" do
    subject(:process!) { class_import.process! }

    let(:file) { "valid.csv" }
    let(:configured_job) { instance_double(ActiveJob::ConfiguredJob) }

    before do
      allow(PDSCascadingSearchJob).to receive(:set).with(
        queue: :imports
      ).and_return(configured_job)
      allow(configured_job).to receive(:perform_later)
    end

    context "when pds_search_during_import flag is enabled" do
      before { Flipper.enable(:pds_search_during_import) }
      after { Flipper.disable(:pds_search_during_import) }

      it "enqueues PDSCascadingSearchJob for each changeset with a postcode" do
        process!

        expect(configured_job).to have_received(:perform_later).exactly(3).times
        without_postcode =
          PatientChangeset.select { it.given_name == "Gae" }.sole

        expect(without_postcode.search_results.count).to eq(1)
        expect(without_postcode.search_results.first["result"]).to eq(
          "no_postcode"
        )
      end
    end

    context "when pds_search_during_import flag is disabled" do
      before { Flipper.disable(:pds_search_during_import) }

      it "enqueues ReviewPatientChangesetJob for each changeset" do
        expect { process! }.to have_enqueued_job(
          ReviewPatientChangesetJob
        ).exactly(4).times

        expect(configured_job).not_to have_received(:perform_later)
      end
    end
  end

  describe "#pds_match_rate" do
    subject(:pds_match_rate) { class_import.pds_match_rate }

    context "when there are no changesets" do
      it { should eq(0) }
    end

    context "with some changesets" do
      before do
        create_list(
          :patient_changeset,
          4,
          :with_pds_match,
          import: class_import
        )
        create_list(:patient_changeset, 6, import: class_import)
      end

      it "returns percentage" do
        expect(pds_match_rate).to eq(40.0)
      end
    end

    context "with only some attempted searches" do
      before do
        create_list(
          :patient_changeset,
          4,
          :with_pds_match,
          import: class_import
        )
        create_list(
          :patient_changeset,
          6,
          :without_pds_search_attempted,
          import: class_import
        )
      end

      it "returns 100" do
        expect(pds_match_rate).to eq(100)
      end
    end
  end

  describe "#validate_pds_match_rate!" do
    subject(:validate_pds_match_rate!) { class_import.validate_pds_match_rate! }

    context "when match rate is equal to threshold" do
      before do
        create_list(
          :patient_changeset,
          7,
          :with_pds_match,
          import: class_import
        )
        create_list(:patient_changeset, 3, import: class_import)
      end

      it "does not mark as low_pds_match_rate" do
        validate_pds_match_rate!
        expect(class_import.reload.status).not_to eq("low_pds_match_rate")
      end
    end

    context "when match rate is below threshold and enough changesets" do
      before do
        create_list(
          :patient_changeset,
          6,
          :with_pds_match,
          import: class_import
        )
        create_list(:patient_changeset, 4, import: class_import)
      end

      it "marks the import as low_pds_match_rate" do
        validate_pds_match_rate!
        expect(class_import.reload.status).to eq("low_pds_match_rate")
      end
    end

    context "when there are fewer than 10 changesets" do
      before { create_list(:patient_changeset, 5, import: class_import) }

      it "skips validation" do
        validate_pds_match_rate!
        expect(class_import.reload.status).not_to eq("low_pds_match_rate")
      end
    end
  end

  describe "#validate_changeset_uniqueness!" do
    subject(:validate_changeset_uniqueness!) do
      class_import.validate_changeset_uniqueness!
    end

    context "when all rows are unique" do
      before { create_list(:patient_changeset, 3, import: class_import) }

      it "does not mark the import as changesets_are_invalid" do
        validate_changeset_uniqueness!
        expect(class_import.reload.status).not_to eq("changesets_are_invalid")
        expect(class_import.serialized_errors).to be_nil.or eq({})
      end
    end

    context "when duplicate NHS numbers exist" do
      before do
        create(
          :patient_changeset,
          data: {
            upload: {
              child: {
                nhs_number: "1234567890"
              }
            }
          },
          import: class_import
        )
        create(
          :patient_changeset,
          data: {
            upload: {
              child: {
                nhs_number: "1234567890"
              }
            }
          },
          import: class_import
        )
        create(:patient_changeset, import: class_import)
      end

      it "marks the import as changesets_are_invalid and records errors" do
        validate_changeset_uniqueness!

        expect(class_import.reload.status).to eq("changesets_are_invalid")
        expect(class_import.serialized_errors.values.flatten).to include(
          /The details on this row match row \d+\. Mavis has found the NHS number 1234567890\./
        )
      end
    end

    context "when duplicate Mavis patient records exist" do
      before do
        patient = create(:patient)
        create(:patient_changeset, import: class_import, patient:)
        create(:patient_changeset, import: class_import, patient:)
      end

      it "marks the import as changesets_are_invalid and includes Mavis duplicate error" do
        validate_changeset_uniqueness!

        expect(class_import.reload.status).to eq("changesets_are_invalid")
        expect(class_import.serialized_errors.values.flatten).to include(
          /The record on this row appears to be a duplicate of row \d+\./
        )
      end
    end
  end
end
