# frozen_string_literal: true

# == Schema Information
#
# Table name: school_moves_exports
#
#  id         :bigint           not null, primary key
#  date_from  :date
#  date_to    :date
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
describe SchoolMovesExport do
  describe "#name" do
    subject { described_class.new.name }

    it { should eq("School moves") }
  end

  describe "#filename" do
    subject(:filename) { export.filename }

    context "with date range" do
      let(:export) do
        described_class.new(
          date_from: Date.new(2024, 1, 1),
          date_to: Date.new(2025, 12, 31)
        )
      end

      it { should eq("school_moves_export_2024-01-01_to_2025-12-31.csv") }
    end

    context "without dates" do
      let(:export) { described_class.new }

      it { should eq("school_moves_export.csv") }
    end
  end
end
