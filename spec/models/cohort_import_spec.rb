# frozen_string_literal: true

# == Schema Information
#
# Table name: cohort_imports
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
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  team_id                      :bigint           not null
#  uploaded_by_user_id          :bigint           not null
#
# Indexes
#
#  index_cohort_imports_on_team_id              (team_id)
#  index_cohort_imports_on_uploaded_by_user_id  (uploaded_by_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploaded_by_user_id => users.id)
#
describe CohortImport do
  subject(:cohort_import) { create(:cohort_import, csv:, team:) }

  let(:programmes) { [Programme.hpv] }
  let(:team) { create(:team, programmes:) }

  let(:file) { "valid.csv" }
  let(:csv) { fixture_file_upload("cohort_import/#{file}") }
  let(:academic_year) { AcademicYear.current }

  # Ensure location URN matches the URN in our fixture files
  let!(:location) { create(:gias_school, urn: "123456", team:) } # rubocop:disable RSpec/LetSetup

  it_behaves_like "a CSVImportable model"

  describe "#parse_rows!" do
    subject(:parse_rows!) { cohort_import.parse_rows! }

    before { parse_rows! }

    describe "with invalid fields" do
      let(:file) { "invalid_fields.csv" }

      it "populates rows" do
        expect(cohort_import).to be_invalid
        expect(cohort_import.rows).not_to be_empty
      end

      it "is invalid" do
        expect(cohort_import).not_to be_valid
      end
    end

    describe "with unrecognised fields" do
      let(:file) { "valid_extra_fields.csv" }

      it "populates rows" do
        expect(cohort_import).to be_valid
      end
    end

    describe "with an instruction row, otherwise valid" do
      let(:file) { "valid_instruction_row.csv" }

      it "populates rows" do
        expect(cohort_import).to be_valid
        expect(cohort_import.rows.count).to eq(1)
      end
    end

    describe "with an instruction row and an error" do
      let(:file) { "invalid_instruction_row.csv" }

      it "populates rows" do
        expect(cohort_import).not_to be_valid
        expect(cohort_import.rows.count).to eq(1)
      end

      it "shows the right error information" do
        expect(cohort_import.errors.count).to eq(1)
        expect(cohort_import.errors.to_a[0]).to start_with("Row 3")
      end
    end

    describe "with valid fields" do
      let(:file) { "valid.csv" }

      it "is valid" do
        expect(cohort_import).to be_valid
      end
    end

    describe "with minimal fields" do
      let(:file) { "valid_minimal.csv" }

      it "is valid" do
        expect(cohort_import).to be_valid
        expect(cohort_import.rows.count).to eq(1)
      end
    end

    describe "with minimal fields and an error" do
      let(:file) { "invalid_minimal.csv" }

      it "populates rows" do
        expect(cohort_import).not_to be_valid
        expect(cohort_import.rows.count).to eq(1)
      end

      it "shows the right error information" do
        expect(cohort_import.errors.count).to eq(1)
        expect(cohort_import.errors.to_a[0]).to start_with("Row 2")
      end
    end
  end

  describe "#process!" do
    subject(:process!) { cohort_import.process! }

    let(:configured_job) { instance_double(ActiveJob::ConfiguredJob) }
    let(:file) { "valid.csv" }

    before do
      allow(PDSCascadingSearchJob).to receive(:set).with(
        queue: :imports
      ).and_return(configured_job)
      allow(configured_job).to receive(:perform_later)
    end

    context "when pds_search_during_import flag is enabled" do
      before do
        Flipper.enable(:pds)
        Flipper.enable(:pds_search_during_import)
      end

      it "enqueues PDSCascadingSearchJob for each changeset" do
        process!

        expect(configured_job).to have_received(:perform_later).exactly(3).times
      end
    end

    context "when pds_search_during_import flag is disabled" do
      before { Flipper.disable(:pds_search_during_import) }

      it "enqueues ReviewPatientChangesetJob for each changeset" do
        expect { process! }.to have_enqueued_job(
          ReviewPatientChangesetJob
        ).exactly(3).times
      end
    end
  end
end
