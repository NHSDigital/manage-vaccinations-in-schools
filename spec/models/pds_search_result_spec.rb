# frozen_string_literal: true

# == Schema Information
#
# Table name: pds_search_results
#
#  id          :bigint           not null, primary key
#  import_type :string
#  nhs_number  :string
#  result      :integer          not null
#  step        :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  import_id   :bigint
#  patient_id  :bigint           not null
#
# Indexes
#
#  index_pds_search_results_on_import      (import_type,import_id)
#  index_pds_search_results_on_patient_id  (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
describe PDSSearchResult, type: :model do
  subject(:pds_search_result) { build(:pds_search_result) }

  describe "associations" do
    it { should belong_to(:patient) }
    it { should belong_to(:import).optional }
  end

  describe ".grouped_sets" do
    subject(:grouped_sets) { described_class.grouped_sets }

    let(:patient) { create(:patient) }

    context "with no records" do
      it { should be_empty }
    end

    context "with records grouped by import" do
      let(:import) { create(:class_import) }

      before do
        create(:pds_search_result, patient:, import:)
        create(:pds_search_result, patient:, import:)
      end

      it "groups records by import" do
        expect(grouped_sets.size).to eq(1)
        expect(grouped_sets.first.size).to eq(2)
      end
    end

    context "with records grouped by date" do
      before do
        travel_to(1.day.ago) do
          create(:pds_search_result, patient:, import: nil)
        end
        create(:pds_search_result, patient:, import: nil)
      end

      it "groups records by date when no import" do
        expect(grouped_sets.size).to eq(2)
        expect(grouped_sets.all? { |set| set.size == 1 }).to be(true)
      end
    end
  end

  describe ".latest_set" do
    subject(:latest_set) { described_class.latest_set }

    let(:patient) { create(:patient) }

    context "with no records" do
      it { should be_nil }
    end

    context "with multiple sets" do
      before do
        create(
          :pds_search_result,
          patient:,
          import: nil,
          created_at: 4.days.ago
        )
        create(:pds_search_result, patient:, import: nil, created_at: 1.day.ago)
      end

      it "returns the most recent set" do
        expect(latest_set.size).to eq(1)
        expect(latest_set.first.created_at.to_date).to eq(1.day.ago.to_date)
      end
    end
  end

  describe "#pds_nhs_number" do
    subject(:pds_nhs_number) { pds_search_result.pds_nhs_number }

    let(:pds_search_result) { create(:pds_search_result, patient:, import:) }
    let(:patient) { create(:patient) }
    let(:import) { create(:class_import) }

    context "without a changeset" do
      it { should be_nil }
    end

    context "with a changeset" do
      before do
        create(
          :patient_changeset,
          patient:,
          import:,
          pds_nhs_number: "9449304130"
        )
      end

      it { should eq("9449304130") }
    end
  end

  describe "#changeset" do
    subject(:changeset) { pds_search_result.changeset }

    let(:pds_search_result) { create(:pds_search_result, patient:, import:) }
    let(:patient) { create(:patient) }
    let(:import) { create(:class_import) }

    context "without import_id" do
      let(:pds_search_result) do
        create(:pds_search_result, patient:, import: nil)
      end

      it { should be_nil }
    end

    context "with matching changeset" do
      let!(:patient_changeset) { create(:patient_changeset, patient:, import:) }

      it { should eq(patient_changeset) }
    end

    context "without matching changeset" do
      it { should be_nil }
    end
  end

  describe "#timeline_item" do
    subject(:timeline_item) { pds_search_result.timeline_item }

    let(:pds_search_result) do
      create(
        :pds_search_result,
        step: :fuzzy,
        result: :one_match,
        nhs_number: "9449304130"
      )
    end

    it "returns timeline item hash" do
      expect(timeline_item).to include(
        is_past_item: true,
        heading_text: "Fuzzy search",
        description: kind_of(String)
      )
    end
  end
end
