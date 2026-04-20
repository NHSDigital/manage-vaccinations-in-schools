# frozen_string_literal: true

describe Import::CSVData do
  subject(:csv_data) { described_class.new(data) }

  let(:data) { "FIRST_NAME,LAST_NAME\nJane,Doe\nJohn,Smith" }

  describe "#well_formed?" do
    it { should be_well_formed }

    context "with malformed CSV" do
      let(:data) do
        File.read(
          Rails.root.join("spec/fixtures/files/class_import/malformed.csv")
        )
      end

      it { should_not be_well_formed }
    end

    context "with nil data" do
      let(:data) { nil }

      it { should be_well_formed }
    end
  end

  describe "#empty?" do
    it { should_not be_empty }

    context "with only a header row and no data" do
      let(:data) { "FIRST_NAME,LAST_NAME" }

      it { should be_empty }
    end

    context "with nil data" do
      let(:data) { nil }

      it { should be_empty }
    end

    context "with malformed CSV" do
      let(:data) do
        File.read(
          Rails.root.join("spec/fixtures/files/class_import/malformed.csv")
        )
      end

      it { should be_empty }
    end
  end

  describe "#count" do
    it { expect(csv_data.count).to eq(2) }

    context "with only a header row and no data" do
      let(:data) { "FIRST_NAME,LAST_NAME" }

      it { expect(csv_data.count).to eq(0) }
    end

    context "with nil data" do
      let(:data) { nil }

      it { expect(csv_data.count).to eq(0) }
    end
  end

  describe "#has_instruction_row?" do
    it { should_not have_instruction_row }

    context "when the first data row starts with 'Required:'" do
      let(:data) do
        File.read(
          Rails.root.join(
            "spec/fixtures/files/class_import/valid_instruction_row.csv"
          )
        )
      end

      it { should have_instruction_row }
    end

    context "when the first data row starts with 'Optional'" do
      let(:data) do
        "FIRST_NAME,LAST_NAME\nOptional: Free text,Optional: Free text\nJane,Doe"
      end

      it { should have_instruction_row }
    end

    context "when the first data row starts with 'Required' followed by a comma" do
      let(:data) { "FIRST_NAME\nRequired,something\nJane" }

      it { should have_instruction_row }
    end

    context "with nil data" do
      let(:data) { nil }

      it { should_not have_instruction_row }
    end
  end

  describe "#records" do
    it "returns an enumerator of the data rows" do
      expect(csv_data.records.to_a.count).to eq(2)
    end

    context "with trailing blank rows" do
      let(:data) { "FIRST_NAME,LAST_NAME\nJane,Doe\n,\n," }

      it "strips the trailing blank rows" do
        expect(csv_data.records.to_a.count).to eq(1)
      end
    end

    context "with an instruction row" do
      let(:data) do
        File.read(
          Rails.root.join(
            "spec/fixtures/files/class_import/valid_instruction_row.csv"
          )
        )
      end

      it "skips the instruction row" do
        expect(csv_data.records.to_a.count).to eq(1)
      end
    end

    context "with an instruction row and trailing blank rows" do
      let(:data) do
        "FIRST_NAME,LAST_NAME\nRequired: Free text,Required: Free text\nJane,Doe\n,\n,"
      end

      it "skips the instruction row and strips trailing blank rows" do
        expect(csv_data.records.to_a.count).to eq(1)
      end
    end

    context "with blank rows in the middle" do
      let(:data) { "FIRST_NAME,LAST_NAME\nJane,Doe\n,\nJohn,Smith" }

      it "preserves blank rows that are not trailing" do
        expect(csv_data.records.to_a.count).to eq(3)
      end
    end
  end
end
