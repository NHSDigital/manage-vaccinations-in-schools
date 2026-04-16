# frozen_string_literal: true

describe AppCompareConsentFormAndPatientComponent do
  subject { render_inline(component) }

  let(:component) { described_class.new(consent_form:, patient:) }

  let(:consent_form) do
    build(
      :consent_form,
      given_name: "John",
      family_name: "Doe",
      date_of_birth: "2000-01-01",
      address_line_1: "1 Main Street",
      address_line_2: "Area",
      address_town: "Some Town",
      address_postcode: "SW11 1AA",
      school: build(:gias_school, name: "Waterloo Road")
    )
  end

  describe "when the consent form matches the patient" do
    let(:patient) do
      build(
        :patient,
        given_name: consent_form.given_name,
        family_name: consent_form.family_name,
        date_of_birth: consent_form.date_of_birth,
        address_line_1: consent_form.address_line_1,
        address_line_2: consent_form.address_line_2,
        address_town: consent_form.address_town,
        address_postcode: consent_form.address_postcode,
        school: consent_form.school
      )
    end

    it { should have_text("Full nameDOE, John").twice }
    it { should have_text("Date of birth1 January 2000").twice }
    it { should have_text("Address1 Main StreetAreaSome TownSW11 1AA").twice }
    it { should have_text("SchoolWaterloo Road").twice }
  end

  describe "when the consent form does not match the patient" do
    let(:patient) do
      create(
        :patient,
        given_name: "Jane", # different
        family_name: consent_form.family_name,
        date_of_birth: Date.new(2000, 1, 2), # different
        address_line_1: "2 Main Street", # different
        address_line_2: consent_form.address_line_2,
        address_town: consent_form.address_town,
        address_postcode: consent_form.address_postcode,
        school: build(:gias_school, name: "Hogwarts")
      )
    end

    it { should have_text("Full nameDOE, John").once }
    it { should have_text("Full nameDOE, Jane").once }

    it { should have_text("Date of birth1 January 2000").once }
    it { should have_text("Date of birth2 January 2000").once }

    it { should have_text("Address1 Main StreetAreaSome TownSW11 1AA").once }
    it { should have_text("Address2 Main StreetAreaSome TownSW11 1AA").once }

    it { should have_text("SchoolWaterloo Road").once }
    it { should have_text("SchoolHogwarts").once }
  end
end
