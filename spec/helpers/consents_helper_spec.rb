# frozen_string_literal: true

describe ConsentsHelper do
  subject(:reasons) { helper.consent_refusal_reasons(consent) }

  describe "#consent_refusal_reasons" do
    subject(:reasons) { helper.consent_refusal_reasons(consent) }

    context "with a ConsentForm for a school session" do
      let(:session) { create(:session, location: create(:gias_school)) }
      let(:consent) { build(:consent_form, session:) }

      it "includes do_not_want_vaccination_at_school" do
        expect(reasons.map(&:value)).to include(
          "do_not_want_vaccination_at_school"
        )
      end

      it "includes the hint for do_not_want_vaccination_at_school" do
        reason =
          reasons.find { |r| r.value == "do_not_want_vaccination_at_school" }
        expect(reason.hint).to eq(
          "For example, you do not want your child to be vaccinated in a busy environment"
        )
      end
    end

    context "with a ConsentForm for a clinic session" do
      let(:session) { create(:session, location: create(:generic_clinic)) }
      let(:consent) { build(:consent_form, session:) }

      it "does not include do_not_want_vaccination_at_school" do
        expect(reasons.map(&:value)).not_to include(
          "do_not_want_vaccination_at_school"
        )
      end
    end

    context "with any consent form" do
      let(:session) { create(:session) }
      let(:consent) { build(:consent_form, session:) }

      it "includes the hint for will_be_vaccinated_elsewhere" do
        reason = reasons.find { |r| r.value == "will_be_vaccinated_elsewhere" }
        expect(reason.hint).to eq(
          "For example, you've booked your child into a clinic"
        )
      end

      it "does not include hints for other reasons" do
        reasons_without_hints =
          reasons.reject do |r|
            %w[
              will_be_vaccinated_elsewhere
              do_not_want_vaccination_at_school
            ].include?(r.value)
          end
        expect(reasons_without_hints.map(&:hint)).to all(be_nil)
      end
    end
  end

  shared_examples "refusal reason label" do |expected_label|
    it "uses the programme-specific refusal reason label" do
      reason = reasons.find { |reason| reason.value == "contains_gelatine" }
      expect(reason.label).to eq(expected_label) if reason
    end
  end

  describe "#consent_response_tag" do
    subject(:tag_html) { helper.consent_response_tag(consent) }

    context "with a follow_up_requested consent" do
      let(:consent) { build(:consent, :follow_up_requested) }

      it { should include("Follow-up requested") }
      it { should include("nhsuk-tag--orange") }
    end

    context "with a given consent" do
      let(:consent) { build(:consent) }

      it { should include("nhsuk-tag--green") }
    end

    context "with a refused consent" do
      let(:consent) { build(:consent, :refused) }

      it { should include("nhsuk-tag--red") }
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
