# frozen_string_literal: true

describe OrdnanceSurvey::PlacesAPI do
  let(:api_key) { "test_api_key" }

  before { Settings.ordnance_survey.api_key = api_key }

  after { Settings.reload! }

  describe "#find" do
    subject(:find) { described_class.find(query, **options) }

    let(:query) { "1 High Street, London" }
    let(:options) { {} }
    let(:api_url) { "https://api.os.uk" }

    context "when the request is successful" do
      let(:response_body) do
        {
          header: {
            uri:
              "#{api_url}/search/places/v1/find?query=1+High+Street%2C+London&format=json",
            query: "1 High Street, London",
            offset: 0,
            total_results: 1,
            format: "json",
            dataset: "DPA",
            lr: "EN,GB",
            max_results: 100,
            epoch: "111",
            output_srs: "EPSG:27700"
          },
          results: [
            {
              DPA: {
                UPRN: "1000000000",
                UDPRN: "12345",
                ADDRESSBASE: "GB12345678",
                ADDRESSBASE_POSTCODE: "SW1A 1AA",
                BUILDING_NAME: "Test Building",
                BUILDING_NUMBER: "1",
                SUB_BUILDING_NAME: "Flat 1",
                THOROUGHFARE_NAME: "High Street",
                THOROUGHFARE_DESCRIPTOR: "",
                POSTTOWN: "London",
                POSTCODE: "SW1A 1AA",
                POSTCODE_TYPE: "L",
                LATITUDE: 51.5074,
                LONGITUDE: -0.1278,
                X_COORDINATE: 530_000.0,
                Y_COORDINATE: 180_000.0,
                EASTING: 530_000,
                NORTHING: 180_000,
                COUNTRY: "England"
              },
              ADDRESS: "1, High Street, London, SW1A 1AA",
              BUILDING_NUMBER: "1",
              THOROUGHFARE: "High Street",
              LOCALITY: "",
              TOWN: "London",
              POSTCODE: "SW1A 1AA",
              COUNTY: "Greater London",
              COUNTRY: "England",
              UPRN: "1000000000",
              MATCH: 1.0,
              MATCH_DESCRIPTION: "EXACT",
              DISTANCE: 0.0
            }
          ]
        }.to_json
      end

      before do
        stub_request(:get, "#{api_url}/search/places/v1/find").with(
          query: hash_including(query:, format: "json"),
          headers: {
            "Key" => api_key
          }
        ).to_return(
          status: 200,
          body: response_body,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "returns parsed results" do
        response = find

        expect(response[:results].length).to eq(1)
        expect(response[:results][0][:postcode]).to eq("SW1A 1AA")
        expect(response[:results][0][:building_number]).to eq("1")
        expect(response[:results][0][:thoroughfare]).to eq("High Street")
        expect(response[:results][0][:town]).to eq("London")
        expect(response[:results][0][:country]).to eq("England")
        expect(response[:results][0][:uprn]).to eq("1000000000")
        expect(response[:results][0][:match]).to eq(1.0)
        expect(response[:results][0][:match_description]).to eq("EXACT")
      end
    end

    context "when the request is invalid" do
      before do
        stub_request(:get, "#{api_url}/search/places/v1/find").with(
          query: hash_including(query:, format: "json"),
          headers: {
            "Key" => api_key
          }
        ).to_return(
          status: 400,
          body: { error: "Invalid query" }.to_json,
          headers: {
          }
        )
      end

      it "raises an error" do
        expect { find }.to raise_error(Faraday::BadRequestError)
      end
    end

    context "when rate limit is exceeded" do
      before do
        stub_request(:get, "#{api_url}/search/places/v1/find").with(
          query: hash_including(query:, format: "json"),
          headers: {
            "Key" => api_key
          }
        ).to_return(status: 429, body: "Rate limit exceeded", headers: {})
      end

      it "raises an error" do
        expect { find }.to raise_error(Faraday::ClientError)
      end
    end

    context "when there is an unexpected error" do
      before do
        stub_request(:get, "#{api_url}/search/places/v1/find").with(
          query: hash_including(query:, format: "json"),
          headers: {
            "Key" => api_key
          }
        ).to_return(status: 500, body: "Internal Server Error", headers: {})
      end

      it "raises an error" do
        expect { find }.to raise_error(Faraday::ServerError)
      end
    end
  end
end
