# frozen_string_literal: true

describe PDS::Patient do
  describe "#find" do
    subject(:find) { described_class.find("9000000009") }

    let(:json_response) do
      file_fixture("pds/get-patient-response-deceased.json").read
    end

    context "when feature flag is disabled" do
      it { should be_nil }
    end

    context "when feature flag is enabled" do
      before { Flipper.enable(:pds) }

      context "when the patient exists" do
        before do
          allow(NHS::PDS).to receive(:get_patient).and_return(
            instance_double(
              Faraday::Response,
              status: 200,
              body: JSON.parse(json_response)
            )
          )
        end

        it "calls get_patient on PDS library" do
          find
          expect(NHS::PDS).to have_received(:get_patient).with("9000000009")
        end

        it "parses the patient information" do
          expect(find).to have_attributes(
            nhs_number: "9000000009",
            family_name: "Smith",
            date_of_birth: Date.new(2010, 10, 22),
            date_of_death: Date.new(2010, 10, 22),
            restricted: true,
            gp_ods_code: "Y12345"
          )
        end
      end
    end
  end

  describe "#search" do
    subject(:search) do
      described_class.search(
        family_name: "Smith",
        given_name: "John",
        date_of_birth: Date.new(2020, 1, 1),
        address_postcode: "SW11 1AA"
      )
    end

    let(:json_response) do
      file_fixture("pds/search-patients-response.json").read
    end

    context "when feature flag is disabled" do
      it { should be_nil }
    end

    context "when feature flag is enabled" do
      before { Flipper.enable(:pds) }

      context "when the patient exists" do
        before do
          allow(NHS::PDS).to receive(:search_patients).and_return(
            instance_double(
              Faraday::Response,
              status: 200,
              body: JSON.parse(json_response)
            )
          )
        end

        it "calls find on PDS library" do
          search
          expect(NHS::PDS).to have_received(:search_patients).with(
            {
              "_history" => true,
              "address-postalcode" => "SW11 1AA",
              "birthdate" => "eq2020-01-01",
              "family" => "Smith",
              "given" => "John"
            }
          )
        end

        it "parses the patient information" do
          expect(search).to have_attributes(
            nhs_number: "9449306168",
            family_name: "LAWMAN",
            date_of_birth: Date.new(1939, 1, 9),
            date_of_death: nil,
            restricted: false,
            gp_ods_code: "H81109"
          )
        end
      end
    end
  end
end
