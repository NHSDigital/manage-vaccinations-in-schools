# frozen_string_literal: true

# == Schema Information
#
# Table name: parent_relationships
#
#  id                           :bigint           not null, primary key
#  contact_method_other_details :text
#  contact_method_type          :string
#  email                        :string
#  full_name                    :string
#  other_name                   :string
#  phone                        :string
#  phone_receive_updates        :string
#  type                         :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  parent_id                    :bigint           not null
#  patient_id                   :bigint           not null
#
# Indexes
#
#  index_parent_relationships_on_parent_id_and_patient_id  (parent_id,patient_id) UNIQUE
#  index_parent_relationships_on_patient_id                (patient_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => parents.id)
#  fk_rails_...  (patient_id => patients.id)
#

describe ParentRelationship do
  subject(:parent_relationship) { build(:parent_relationship) }

  describe "validations" do
    it { should be_valid }

    context "when type is other" do
      subject(:parent_relationship) do
        build(:parent_relationship, type: "other")
      end

      it { should validate_presence_of(:other_name) }
    end

    context "when type is not other" do
      subject(:parent_relationship) do
        build(:parent_relationship, type: "mother", other_name: "Mother")
      end

      it "sets the other name to nil" do
        expect(parent_relationship.valid?).to be true
        expect(parent_relationship.other_name).to be_nil
      end
    end
  end

  describe "#label" do
    subject(:label) { parent_relationship.label }

    context "with a father" do
      let(:parent_relationship) { build(:parent_relationship, :father) }

      it { should eq("Dad") }
    end

    context "with a mother" do
      let(:parent_relationship) { build(:parent_relationship, :mother) }

      it { should eq("Mum") }
    end

    context "with a guardian" do
      let(:parent_relationship) { build(:parent_relationship, :guardian) }

      it { should eq("Guardian") }
    end

    context "with an other" do
      let(:parent_relationship) do
        build(:parent_relationship, :other, other_name: "Grandparent")
      end

      it { should eq("Other – Grandparent") }
    end

    context "with an unknown" do
      let(:parent_relationship) { build(:parent_relationship, :unknown) }

      it { should eq("Unknown") }
    end
  end
end
