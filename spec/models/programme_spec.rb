# frozen_string_literal: true

# == Schema Information
#
# Table name: programmes
#
#  id         :bigint           not null, primary key
#  type       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_programmes_on_type  (type) UNIQUE
#

describe Programme do
  subject(:programme) { described_class.sample }

  describe "#all_as_variants" do
    subject(:all_as_variants) { described_class.all_as_variants }

    it "returns all variants" do
      expect(all_as_variants).to contain_exactly(
        described_class.flu,
        described_class.hpv,
        described_class.td_ipv,
        described_class.menacwy,
        Programme::Variant.new(described_class.mmr, variant_type: "mmr"),
        Programme::Variant.new(described_class.mmr, variant_type: "mmrv")
      )
    end
  end

  describe "#find" do
    subject(:find) { described_class.find(type) }

    context "with a known type" do
      let(:type) { Programme::TYPES.sample }

      it { should_not be_nil }
    end

    context "with an unknown type" do
      let(:type) { "unknown" }

      it "raises an error" do
        expect { find }.to raise_error(Programme::InvalidType)
      end
    end

    context "when programme is MMR and MMRV support is enabled" do
      let(:type) { "mmr" }

      context "without any additional criteria" do
        it "doesn't return a variant" do
          expect(find).to be_a(described_class)
        end
      end

      context "when patient was born before 1 January 2020" do
        subject(:find) { described_class.find(type, patient:) }

        let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month }
        let(:patient) { create(:patient, date_of_birth:) }

        it "returns an MMR variant" do
          expect(find.variant_type).to eq("mmr")
        end
      end

      context "when patient was born after 1 January 2020" do
        subject(:find) { described_class.find(type, patient:) }

        let(:date_of_birth) { Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month }
        let(:patient) { create(:patient, date_of_birth:) }

        it "returns an MMRV variant" do
          expect(find.variant_type).to eq("mmrv")
        end
      end
    end
  end

  describe "#name" do
    subject { programme.name }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should eq("Flu") }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should eq("HPV") }
    end

    context "with an MMR programme" do
      let(:programme) { described_class.mmr }

      it { should eq("MMR(V)") }
    end
  end

  describe "#name_in_sentence" do
    subject(:name) { programme.name_in_sentence }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should eq("flu") }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should eq("HPV") }
    end
  end

  describe "#variants" do
    subject(:variants) { programme.variants }

    context "for flu" do
      let(:programme) { described_class.flu }

      it { should contain_exactly(described_class.flu) }
    end

    context "for Td/IPV" do
      let(:programme) { described_class.td_ipv }

      it { should contain_exactly(described_class.td_ipv) }
    end

    context "for MenACWY" do
      let(:programme) { described_class.menacwy }

      it { should contain_exactly(described_class.menacwy) }
    end

    context "for HPV" do
      let(:programme) { described_class.hpv }

      it { should contain_exactly(described_class.hpv) }
    end

    context "for MMR(V)" do
      let(:programme) { described_class.mmr }

      it do
        expect(variants).to contain_exactly(
          Programme::Variant.new(described_class.mmr, variant_type: "mmr"),
          Programme::Variant.new(described_class.mmr, variant_type: "mmrv")
        )
      end
    end
  end

  describe "#seasonal?" do
    subject { programme.seasonal? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be(true) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be(false) }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be(false) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be(false) }
    end
  end

  describe "#supports_delegation?" do
    subject { programme.supports_delegation? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be(true) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be(false) }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be(false) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be(false) }
    end
  end

  describe "#triage_on_vaccination_history?" do
    subject { programme.triage_on_vaccination_history? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be(false) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be(false) }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be(true) }
    end

    context "with an MMR programme" do
      let(:programme) { described_class.mmr }

      it { should be(false) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be(true) }
    end
  end

  describe "#default_year_groups" do
    subject { programme.default_year_groups }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should eq([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should eq([8, 9, 10, 11]) }
    end

    context "with a MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should eq([9, 10, 11]) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should eq([9, 10, 11]) }
    end
  end

  describe "#vaccine_methods" do
    subject { programme.vaccine_methods }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should contain_exactly("injection", "nasal") }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should contain_exactly("injection") }
    end
  end

  describe "#vaccine_may_contain_gelatine?" do
    subject { programme.vaccine_may_contain_gelatine? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be(true) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be(false) }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be(false) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be(false) }
    end
  end

  describe "#default_dose_sequence" do
    subject(:default_dose_sequence) { programme.default_dose_sequence }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should eq(1) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should eq(1) }
    end

    context "with a MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be_nil }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be_nil }
    end
  end

  describe "#maximum_dose_sequence" do
    subject(:maximum_dose_sequence) { programme.maximum_dose_sequence }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should eq(2) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should eq(3) }
    end

    context "with a MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should eq(3) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should eq(6) }
    end
  end

  describe "#flipper_id" do
    subject { programme.flipper_id }

    context "for flu" do
      let(:programme) { described_class.flu }

      it { should eq("Programme:flu") }
    end

    context "for Td/IPV" do
      let(:programme) { described_class.td_ipv }

      it { should eq("Programme:td_ipv") }
    end

    context "for MenACWY" do
      let(:programme) { described_class.menacwy }

      it { should eq("Programme:menacwy") }
    end

    context "for HPV" do
      let(:programme) { described_class.hpv }

      it { should eq("Programme:hpv") }
    end

    context "for MMR" do
      let(:programme) { described_class.mmr }

      it { should eq("Programme:mmr") }
    end

    context "for MMRV variant" do
      let(:programme) do
        Programme::Variant.new(described_class.mmr, variant_type: "mmrv")
      end

      it { should eq("ProgrammeVariant:mmrv") }
    end

    context "for MMR variant" do
      let(:programme) do
        Programme::Variant.new(described_class.mmr, variant_type: "mmr")
      end

      it { should eq("ProgrammeVariant:mmr") }
    end
  end

  describe "#multi_dose?" do
    subject { programme.multi_dose? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be(false) }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be(false) }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be(false) }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be(false) }
    end

    context "with an MMR programme" do
      let(:programme) { described_class.mmr }

      it { should be(true) }
    end
  end

  describe "#supports_outbreak?" do
    subject { programme.supports_outbreak? }

    context "with a flu programme" do
      let(:programme) { described_class.flu }

      it { should be false }
    end

    context "with an HPV programme" do
      let(:programme) { described_class.hpv }

      it { should be false }
    end

    context "with an MenACWY programme" do
      let(:programme) { described_class.menacwy }

      it { should be false }
    end

    context "with an Td/IPV programme" do
      let(:programme) { described_class.td_ipv }

      it { should be false }
    end

    context "with an MMR programme" do
      let(:programme) { described_class.mmr }

      it { should be true }
    end
  end
end
