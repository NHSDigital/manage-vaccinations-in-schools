# frozen_string_literal: true

describe ConsentConfirmRefusalForm do
  subject(:form) { described_class.new }

  describe "validations" do
    it "is invalid without confirmed" do
      expect(form).not_to be_valid
    end

    context "with confirmed set to true" do
      before { form.confirmed = "true" }

      it { should be_valid }
    end

    context "with confirmed set to false" do
      before { form.confirmed = "false" }

      it { should be_valid }
    end

    context "with notes exceeding 1000 characters" do
      before do
        form.confirmed = "true"
        form.notes = "a" * 1001
      end

      it { should_not be_valid }
    end

    context "with notes at exactly 1000 characters" do
      before do
        form.confirmed = "true"
        form.notes = "a" * 1000
      end

      it { should be_valid }
    end
  end

  describe "#confirmed?" do
    it "returns true when confirmed is 'true'" do
      form.confirmed = "true"
      expect(form.confirmed?).to be true
    end

    it "returns false when confirmed is 'false'" do
      form.confirmed = "false"
      expect(form.confirmed?).to be false
    end

    it "returns false when confirmed is nil" do
      expect(form.confirmed?).to be false
    end
  end
end
