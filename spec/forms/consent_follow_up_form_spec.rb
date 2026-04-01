# frozen_string_literal: true

describe ConsentFollowUpForm do
  subject(:form) { described_class.new }

  describe "validations" do
    it "is invalid without decision_stands" do
      expect(form).not_to be_valid
    end

    context "with decision_stands set to true" do
      before { form.decision_stands = "true" }

      it { should be_valid }
    end

    context "with decision_stands set to false" do
      before { form.decision_stands = "false" }

      it { should be_valid }
    end

    context "with an invalid decision_stands value" do
      before { form.decision_stands = "maybe" }

      it { should_not be_valid }
    end
  end

  describe "#decision_stands?" do
    it "returns true when decision_stands is 'true'" do
      form.decision_stands = "true"
      expect(form.decision_stands?).to be true
    end

    it "returns false when decision_stands is 'false'" do
      form.decision_stands = "false"
      expect(form.decision_stands?).to be false
    end

    it "returns false when decision_stands is nil" do
      expect(form.decision_stands?).to be false
    end
  end
end
