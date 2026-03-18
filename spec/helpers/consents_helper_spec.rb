# frozen_string_literal: true

describe ConsentsHelper do
  subject(:reasons) { helper.consent_refusal_reasons(consent) }

  shared_examples "refusal reason label" do |expected_label|
    it "uses the programme-specific refusal reason label" do
      reason = reasons.find { |reason| reason.value == "contains_gelatine" }
      expect(reason.label).to eq(expected_label) if reason
    end
  end

  describe "#refusal_reason_label" do
    context "consent record" do
      let(:consent) { build(:consent, programme:) }

      context "when the programme is flu" do
        let(:programme) { Programme.flu }

        include_examples "refusal reason label",
                         "I’m concerned the nasal vaccine contains gelatine"
      end

      context "when the programme is MMR" do
        let(:programme) do
          Programme::Variant.new(Programme.mmr, variant_type: "mmr")
        end

        include_examples(
          "refusal reason label",
          "I’m concerned the vaccine contains gelatine"
        )
      end

      context "when the programme is MMRV" do
        let(:programme) do
          Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
        end

        include_examples(
          "refusal reason label",
          "I’m concerned the vaccine contains gelatine"
        )
      end

      context "when the programme is not flu or MMR" do
        let(:programme) { Programme.hpv }

        include_examples "refusal reason label",
                         "I’m concerned the vaccine contains gelatine"
      end
    end

    context "consent_form record" do
      let(:consent) { build(:consent_form, programmes: [programme]) }

      context "when the programme is flu" do
        let(:programme) { Programme.flu }

        include_examples "refusal reason label",
                         "I’m concerned the nasal vaccine contains gelatine"
      end

      context "when the programme is MMR" do
        let(:programme) do
          Programme::Variant.new(Programme.mmr, variant_type: "mmr")
        end

        include_examples(
          "refusal reason label",
          "I’m concerned the vaccine contains gelatine"
        )
      end

      context "when the programme is MMRV" do
        let(:programme) do
          Programme::Variant.new(Programme.mmr, variant_type: "mmrv")
        end

        include_examples(
          "refusal reason label",
          "I’m concerned the vaccine contains gelatine"
        )
      end

      context "when the programme is not flu or MMR" do
        let(:programme) { Programme.hpv }

        include_examples "refusal reason label",
                         "I’m concerned the vaccine contains gelatine"
      end
    end
  end
end
