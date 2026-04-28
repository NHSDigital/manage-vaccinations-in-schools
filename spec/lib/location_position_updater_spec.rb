# frozen_string_literal: true

describe LocationPositionUpdater do
  describe "#call" do
    subject(:call) { described_class.call(location) }

    let(:location) do
      create(
        :community_clinic,
        name: "Westminster Clinic",
        address_line_1: "1 High Street",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        position: nil
      )
    end

    context "when location has no address" do
      let(:location) { create(:community_clinic, :without_address) }

      it "raises an error" do
        expect { call }.to raise_error(LocationPositionUpdater::MissingAddress)
      end

      it "does not call the API" do
        expect(OrdnanceSurvey::PlacesAPI).not_to receive(:find)
        expect { call }.to raise_error(LocationPositionUpdater::MissingAddress)
      end

      it "does not update the position" do
        expect { call }.to raise_error(
          LocationPositionUpdater::MissingAddress
        ).and not_change(location, :position)
      end
    end

    context "when API returns coordinates" do
      let(:response) do
        {
          header: {
            total_results: 1
          },
          results: [{ dpa: { lat: 51.5074, lng: -0.1278 } }]
        }
      end

      before do
        allow(OrdnanceSurvey::PlacesAPI).to receive(:find).and_return(response)
      end

      it "calls the API with the address" do
        expect(OrdnanceSurvey::PlacesAPI).to receive(:find).with(
          "Westminster Clinic, 1 High Street, London, SW1A 1AA"
        )
        call
      end

      it "updates the location's position" do
        expect { call }.to change(location, :position).from(nil).to(
          an_instance_of(RGeo::Geographic::SphericalPointImpl)
        )
        expect(location.position.x).to eq(-0.1278)
        expect(location.position.y).to eq(51.5074)
      end
    end

    context "when API returns no results" do
      let(:response) { { header: { total_results: 0 }, results: [] } }

      before do
        allow(OrdnanceSurvey::PlacesAPI).to receive(:find).and_return(response)
      end

      it "raises an error" do
        expect { call }.to raise_error(LocationPositionUpdater::NoResults)
      end
    end

    context "when API returns a result without coordinates" do
      let(:response) do
        { header: { total_results: 1 }, results: [{ dpa: {} }] }
      end

      before do
        allow(OrdnanceSurvey::PlacesAPI).to receive(:find).and_return(response)
      end

      it "raises an error" do
        expect { call }.to raise_error(LocationPositionUpdater::NoResults)
      end
    end

    context "when location has partial address" do
      let(:location) do
        create(
          :community_clinic,
          name: "Westminster Clinic",
          address_line_1: "1 High Street",
          address_town: nil,
          address_postcode: "SW1A 1AA",
          position: nil
        )
      end

      let(:response) do
        {
          header: {
            total_results: 1
          },
          results: [{ dpa: { lat: 51.5074, lng: -0.1278 } }]
        }
      end

      before do
        allow(OrdnanceSurvey::PlacesAPI).to receive(:find).and_return(response)
      end

      it "calls the API with partial address" do
        expect(OrdnanceSurvey::PlacesAPI).to receive(:find).with(
          "Westminster Clinic, 1 High Street, SW1A 1AA"
        )
        call
      end

      it "updates the location position" do
        expect { call }.to change(location, :position).from(nil).to(
          an_instance_of(RGeo::Geographic::SphericalPointImpl)
        )
        expect(location.position.x).to eq(-0.1278)
        expect(location.position.y).to eq(51.5074)
      end
    end
  end
end
