# frozen_string_literal: true

describe API::Testing::TeamsController do
  include ActiveJob::TestHelper

  before { Flipper.enable(:testing_api) }
  after { Flipper.disable(:testing_api) }

  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  describe "DELETE #destroy_locations" do
    let(:team) { create(:team, workgroup: "r1l") }

    let!(:base_location) do
      create(:gias_school, team:, name: "Hogwarts", urn: "123456")
    end

    let!(:site_location) do
      create(:gias_school, team:, name: "Hogwarts 2", urn: "123456", site: "B")
    end

    context "when keep_base_locations is true" do
      subject(:call) do
        delete :destroy_locations,
               params: {
                 workgroup: "r1l",
                 keep_base_locations: "true"
               }
      end

      it "keeps the base location and removes the site designation" do
        expect { call }.to(change(Location, :count).by(-1))

        expect(Location.find(base_location.id).site).to be_nil
        expect { Location.find(site_location.id) }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end
    end

    context "when keep_base_locations is false" do
      subject(:call) do
        delete :destroy_locations,
               params: {
                 workgroup: "r1l",
                 keep_base_locations: "false"
               }
      end

      it "deletes all locations" do
        expect { call }.to change(Location.gias_school, :count).by(-2)

        expect { Location.find(base_location.id) }.to raise_error(
          ActiveRecord::RecordNotFound
        )
        expect { Location.find(site_location.id) }.to raise_error(
          ActiveRecord::RecordNotFound
        )
      end
    end
  end
end
