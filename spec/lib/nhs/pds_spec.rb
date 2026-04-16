# frozen_string_literal: true

describe NHS::PDS do
  describe "#get_patient" do
    subject(:get_patient) { described_class.get_patient("9000000009") }

    context "when feature flag is disabled" do
      it { should be_nil }
    end

    context "when feature flag is enabled" do
      before { Flipper.enable(:pds) }

      context "with a successful response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/get-patient-response.json"),
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "sends a GET request to retrieve a patient by their NHS number" do
          response = get_patient
          expect(response.body).to include("id" => "9000000009")
        end
      end

      context "with an invalid NHS number" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/invalid-nhs-number-response.json"),
            status: 400,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "raises an error" do
          expect { get_patient }.to raise_error(NHS::PDS::InvalidNHSNumber)
        end
      end

      context "with an invalidated resource response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/invalid-patient-response.json"),
            status: 404,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "raises an error" do
          expect { get_patient }.to raise_error(NHS::PDS::InvalidatedResource)
        end
      end

      context "with a resource not found response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient/9000000009"
          ).to_return(
            body: file_fixture("pds/not-found-patient-response.json"),
            status: 404,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "raises an error" do
          expect { get_patient }.to raise_error(NHS::PDS::PatientNotFound)
        end
      end
    end
  end

  describe "#search_patients" do
    subject(:search_patients) do
      described_class.search_patients(
        family: "Lawman",
        gender: "female",
        birthdate: "eq1939-01-09"
      )
    end

    context "when feature flag is disabled" do
      it { should be_nil }
    end

    context "when feature flag is enabled" do
      before { Flipper.enable(:pds) }

      context "with a successful response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient"
          ).with(
            query: {
              birthdate: "eq1939-01-09",
              family: "Lawman",
              gender: "female"
            }
          ).to_return(
            body: file_fixture("pds/search-patients-response.json"),
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "sends a GET request to with the provided attributes" do
          response = search_patients
          expect(response.body).to include("total" => 1)
        end
      end

      context "with an invalid search data response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient"
          ).with(
            query: {
              birthdate: "eq1939-01-09",
              family: "Lawman",
              gender: "female"
            }
          ).to_return(
            body: file_fixture("pds/invalid-search-data.json"),
            status: 400,
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "raises an error" do
          expect { search_patients }.to raise_error(NHS::PDS::InvalidSearchData)
        end
      end

      context "with a too many matches response" do
        before do
          stub_request(
            :get,
            "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient"
          ).with(
            query: {
              birthdate: "eq1939-01-09",
              family: "Lawman",
              gender: "female"
            }
          ).to_return(
            body: file_fixture("pds/too-many-matches.json"),
            headers: {
              "Content-Type" => "application/fhir+json"
            }
          )
        end

        it "raises an error" do
          expect { search_patients }.to raise_error(NHS::PDS::TooManyMatches)
        end
      end

      it "raises an error if an unrecognised attribute is provided" do
        expect {
          described_class.search_patients(
            given: "Eldreda",
            family_name: "Lawman",
            date_of_birth: "1939-01-09"
          )
        }.to raise_error("Unrecognised attributes: family_name, date_of_birth")
      end
    end
  end
end
