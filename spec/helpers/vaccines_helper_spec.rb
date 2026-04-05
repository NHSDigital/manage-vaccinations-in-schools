# frozen_string_literal: true

describe VaccinesHelper do
  let(:vaccine) { Vaccine.find_by!(brand: "Fluenz") }

  describe "#vaccine_heading" do
    subject { helper.vaccine_heading(vaccine) }

    it { should eq("Fluenz (Flu)") }
  end

  describe "#vaccine_method" do
    subject { helper.vaccine_method(vaccine) }

    context "with an injection vaccine" do
      let(:vaccine) { Vaccine.find_by!(brand: "Gardasil 9") }

      it { should eq("injection") }
    end

    context "with a nasal vaccine" do
      it { should eq("nasal spray") }
    end

    context "with nil" do
      let(:vaccine) { nil }

      it { should be_nil }
    end
  end

  describe "#vaccine_side_effects_list" do
    subject(:side_effects_list) { helper.vaccine_side_effects_list(vaccine) }

    context "with a vaccine that has side effects" do
      let(:vaccine) do
        Vaccine
          .find_by!(brand: "Gardasil 9")
          .tap { |v| v.update!(side_effects: %w[swelling headache]) }
      end

      it do
        expect(side_effects_list).to eq(
          "- a headache\n- swelling or pain where the injection was given"
        )
      end
    end

    context "with nil" do
      let(:vaccine) { nil }

      it { should be_nil }
    end

    context "with a vaccine that has no side effects" do
      let(:vaccine) { build(:vaccine, side_effects: []) }

      it { should eq("") }
    end
  end
end
