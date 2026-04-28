# frozen_string_literal: true

describe LocationPositionUpdaterJob do
  describe "#perform" do
    subject(:perform) { described_class.new.perform(location.id) }

    let(:location) { create(:community_clinic, position: nil) }

    context "when the location has an address" do
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

      it "calls LocationPositionUpdater with the location" do
        expect(LocationPositionUpdater).to receive(:call).with(location)
        perform
      end

      it "updates the location position" do
        expect { perform }.to change { location.reload.position }.from(nil).to(
          an_instance_of(RGeo::Geographic::SphericalPointImpl)
        )
      end
    end

    context "when there are no results" do
      let(:error) { LocationPositionUpdater::NoResults.new }

      before do
        allow(LocationPositionUpdater).to receive(:call).and_raise(error)
      end

      context "when not capturing the exception" do
        it "doesn't capture the exception in Sentry" do
          expect(Sentry).not_to receive(:capture_exception)
          perform
        end

        it "does not raise the error" do
          expect { perform }.not_to raise_error
        end
      end

      context "when capturing the exception" do
        before do
          Settings.location_position_updater_job.capture_exception = true
        end

        after { Settings.reload! }

        it "captures the exception in Sentry at warning level" do
          expect(Sentry).to receive(:capture_exception).with(
            error,
            level: "warning"
          )
          perform
        end

        it "does not raise the error" do
          expect { perform }.not_to raise_error
        end
      end
    end

    context "when the location has no address" do
      let(:location) { create(:community_clinic, :without_address) }

      it "re-raises the error" do
        expect { perform }.to raise_error(
          LocationPositionUpdater::MissingAddress
        )
      end
    end
  end
end
