# frozen_string_literal: true

describe ProgrammesHelper do
  describe "#programme_name_for_parents" do
    subject { helper.programme_name_for_parents(programme) }

    context "with a programme that has no NHS.uk name" do
      let(:programme) { Programme.hpv }

      it { should eq("HPV") }
    end

    context "with flu" do
      let(:programme) { Programme.flu }

      it { should eq("flu") }
    end

    context "with a programme that has an NHS.uk name" do
      let(:programme) { Programme.td_ipv }

      it { should eq("Td/IPV (3-in-1 teenage booster)") }
    end

    context "with an MMR variant" do
      let(:programme) do
        Programme.find("mmr", disease_types: %w[measles mumps rubella])
      end

      it { should eq("MMR") }
    end

    context "with an MMRV variant" do
      let(:programme) do
        Programme.find(
          "mmr",
          disease_types: %w[measles mumps rubella varicella]
        )
      end

      it { should eq("MMRV") }
    end
  end
end
