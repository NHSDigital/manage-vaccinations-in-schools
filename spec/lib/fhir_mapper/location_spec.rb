# frozen_string_literal: true

describe FHIRMapper::Location do
  describe "#fhir_reference" do
    subject(:fhir_reference) { fhir_mapper.fhir_reference }

    let(:fhir_mapper) { described_class.new(location) }

    describe "identifier" do
      subject(:identifier) { fhir_reference.identifier }

      context "location is a school" do
        let(:location) { create(:gias_school, urn: "654321") }

        its(:system) do
          should eq "https://fhir.hl7.org.uk/Id/urn-school-number"
        end

        its(:value) { should eq "654321" }
      end

      context "location is a community clinic" do
        let(:location) { create(:community_clinic, ods_code: "918273") }

        its(:system) do
          should eq "https://fhir.nhs.uk/Id/ods-organization-code"
        end

        its(:value) { should eq "918273" }

        context "ods code is not set" do
          let(:location) { create(:community_clinic, ods_code: nil) }

          its(:value) { should eq "X99999" }
        end
      end
    end
  end
end
