# frozen_string_literal: true

describe LoggingHelper do
  describe ".id" do
    it "accepts a positive Integer" do
      expect(described_class.id(123)).to eq(id: 123)
    end

    it "accepts a non-empty String" do
      expect(described_class.id("abc")).to eq(id: "abc")
    end

    it "raises TypeError for nil" do
      expect { described_class.id(nil) }.to raise_error(TypeError)
    end

    it "raises TypeError for non-id types" do
      expect { described_class.id(1.5) }.to raise_error(TypeError)
      expect { described_class.id([1]) }.to raise_error(TypeError)
    end

    it "raises ArgumentError for zero or negative Integer" do
      expect { described_class.id(0) }.to raise_error(ArgumentError)
      expect { described_class.id(-1) }.to raise_error(ArgumentError)
    end

    it "raises ArgumentError for empty String" do
      expect { described_class.id("") }.to raise_error(ArgumentError)
    end
  end

  describe ".record" do
    it "returns a hash with the model class name and id" do
      record = build_stubbed(:cohort_import)
      expect(described_class.record(record)).to eq(
        model: "CohortImport",
        id: record.id
      )
    end

    it "raises TypeError when given a non-ApplicationRecord" do
      expect { described_class.record("not a record") }.to raise_error(TypeError)
    end

    it "raises ArgumentError when the record has no id" do
      record = CohortImport.new
      expect { described_class.record(record) }.to raise_error(ArgumentError)
    end
  end

  describe "lifecycle helpers" do
    it "returns the started status" do
      expect(described_class.started_status).to eq(status: "started")
    end

    it "returns the finished status" do
      expect(described_class.finished_status).to eq(status: "finished")
    end

    it "returns the skipped status" do
      expect(described_class.skipped_status).to eq(status: "skipped")
    end

    it "returns the failed status" do
      expect(described_class.failed_status).to eq(status: "failed")
    end
  end

  describe ".duration_ms" do
    it "accepts a non-negative Integer" do
      expect(described_class.duration_ms(100)).to eq(duration_ms: 100)
      expect(described_class.duration_ms(0)).to eq(duration_ms: 0)
    end

    it "accepts a non-negative Float" do
      expect(described_class.duration_ms(123.4)).to eq(duration_ms: 123.4)
    end

    it "raises TypeError for non-numeric input" do
      expect { described_class.duration_ms("100") }.to raise_error(TypeError)
      expect { described_class.duration_ms(nil) }.to raise_error(TypeError)
    end

    it "raises ArgumentError for negative numbers" do
      expect { described_class.duration_ms(-1) }.to raise_error(ArgumentError)
    end
  end

  describe ".count" do
    it "accepts a non-negative Integer" do
      expect(described_class.count(7)).to eq(count: 7)
      expect(described_class.count(0)).to eq(count: 0)
    end

    it "raises TypeError for non-Integer input" do
      expect { described_class.count(1.5) }.to raise_error(TypeError)
      expect { described_class.count("7") }.to raise_error(TypeError)
      expect { described_class.count(nil) }.to raise_error(TypeError)
    end

    it "raises ArgumentError for negative numbers" do
      expect { described_class.count(-1) }.to raise_error(ArgumentError)
    end
  end

  describe "L constant" do
    it "is an alias for LoggingHelper" do
      expect(L).to equal(described_class)
    end
  end
end
