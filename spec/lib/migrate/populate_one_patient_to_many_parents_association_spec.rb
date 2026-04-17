# frozen_string_literal: true

RSpec.describe Migrate::PopulateOnePatientToManyParentsAssociation do
  let(:robbie) do
    create(:patient, given_name: "Robbie", family_name: "Roberts")
  end
  let(:alice) { create(:patient, given_name: "Alice", family_name: "Roberts") }
  let(:colin) { create(:patient, given_name: "Colin", family_name: "Jones") }

  let(:mum_roberts) { create(:parent, family_name: "Roberts") }
  let(:dad_roberts) { create(:parent, family_name: "Roberts") }
  let(:dad_jones) { create(:parent, family_name: "Jones") }
  let(:guardian_jones) { create(:parent, family_name: "Jones") }
  let(:other_jones) { create(:parent, family_name: "Jones") }

  before do
    Flipper.enable(:one_patient_per_parent)

    create(
      :parent_relationship,
      patient: robbie,
      parent: mum_roberts,
      type: "mother"
    )
    create(
      :parent_relationship,
      patient: alice,
      parent: mum_roberts,
      type: "mother"
    )
    create(
      :parent_relationship,
      patient: alice,
      parent: dad_roberts,
      type: "father"
    )
    create(
      :parent_relationship,
      patient: colin,
      parent: dad_jones,
      type: "father"
    )
    create(
      :parent_relationship,
      patient: colin,
      parent: guardian_jones,
      type: "guardian"
    )
    create(
      :parent_relationship,
      patient: colin,
      parent: other_jones,
      type: "other",
      other_name: "Auntie"
    )

    described_class.call
  end

  it "populates the patient_id keys on each existing parent record" do
    expect(mum_roberts.reload.patient_id).to be(robbie.id)
    expect(dad_roberts.reload.patient_id).to be(alice.id)
    expect(dad_jones.reload.patient_id).to be(colin.id)
    expect(guardian_jones.reload.patient_id).to be(colin.id)
    expect(other_jones.reload.patient_id).to be(colin.id)
  end

  it "sets the `type` attribute correctly" do
    expect(mum_roberts.reload.type).to eq("mother")
    expect(dad_roberts.reload.type).to eq("father")
    expect(dad_jones.reload.type).to eq("father")
    expect(guardian_jones.reload.type).to eq("guardian")
    expect(other_jones.reload.type).to eq("other")
  end

  it "sets the `other_name` attribute correctly" do
    expect(mum_roberts.reload.other_name).to be_nil
    expect(dad_roberts.reload.other_name).to be_nil
    expect(dad_jones.reload.other_name).to be_nil
    expect(guardian_jones.reload.other_name).to be_nil
    expect(other_jones.reload.other_name).to eq("Auntie")
  end

  it "creates a new parent record for a parent that was associated with multiple children" do
    expect(Parent.where(email: mum_roberts.email).count).to eq(2)

    new_mum_roberts =
      Parent.where(email: mum_roberts.email).where.not(id: mum_roberts.id).first
    expect(new_mum_roberts.patient_id).to be(alice.id)
    expect(new_mum_roberts.type).to eq("mother")
    expect(new_mum_roberts.other_name).to be_nil
  end
end
