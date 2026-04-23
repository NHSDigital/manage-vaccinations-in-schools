# frozen_string_literal: true

describe CSVParser::Field do
  describe "#to_date" do
    subject(:to_date) { field.to_date }

    let(:field) { described_class.new(value, "A", 2, "date") }

    context "when value is nil" do
      let(:value) { nil }

      it { should be_nil }
    end

    context "when value is blank" do
      let(:value) { "" }

      it { should be_nil }
    end

    context "when value is not a date" do
      let(:value) { "not a date" }

      it { should be_nil }
    end

    context "with format DD/MM/YYYY" do
      let(:value) { "01/02/2025" }

      it { should eq(Date.new(2025, 2, 1)) }
    end

    context "with format YYYY-MM-DD" do
      let(:value) { "2025-02-01" }

      it { should eq(Date.new(2025, 2, 1)) }
    end

    context "with format YYYYMMDD" do
      let(:value) { "20250201" }

      it { should eq(Date.new(2025, 2, 1)) }
    end

    context "with format DD/MM/YY (2-digit year)" do
      let(:value) { "01/02/25" }

      it { should be_nil }
    end

    context "with format YY-MM-DD (2-digit year)" do
      let(:value) { "25-02-01" }

      it { should be_nil }
    end

    context "with format YYMMDD (2-digit year)" do
      let(:value) { "250201" }

      it { should be_nil }
    end

    context "with a 3-digit year" do
      let(:value) { "01/02/999" }

      it { should be_nil }
    end

    context "with an impossible date" do
      let(:value) { "31/02/2025" }

      it { should be_nil }
    end

    context "with an invalid month" do
      let(:value) { "01/13/2025" }

      it { should be_nil }
    end
  end
end
