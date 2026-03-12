# frozen_string_literal: true

describe "/api/testing/locations" do
  before { Flipper.enable(:testing_api) }
  after { Flipper.disable(:testing_api) }

  let(:team) { create(:team) }

  let!(:community_clinic) do
    create(:community_clinic, :open, name: "Location A", team:)
  end
  let!(:generic_clinic) { team.generic_clinic }
  let!(:gp_practice) do
    create(:gp_practice, :closed, name: "Location C", team:)
  end
  let!(:home_educated_school) { team.home_educated_school }
  let!(:primary_school) do
    create(:school, :primary, :closed, name: "Location D")
  end
  let!(:secondary_school) do
    create(:school, :secondary, :closed, name: "Location E")
  end
  let!(:unknown_school) { team.unknown_school }

  describe "GET" do
    it "includes all locations" do
      get "/api/testing/locations"

      expect(response).to have_http_status(:ok)

      locations = JSON.parse(response.body)

      expect(locations).to match_array(
        [
          community_clinic,
          generic_clinic,
          gp_practice,
          home_educated_school,
          primary_school,
          secondary_school,
          unknown_school
        ].map(&:as_json)
      )
    end

    context "when filtering by status" do
      it "includes only relevant locations" do
        get "/api/testing/locations", params: { status: "open" }

        expect(response).to have_http_status(:ok)

        locations = JSON.parse(response.body)

        expect(locations).to eq([community_clinic.as_json])
      end
    end

    context "when filtering by type" do
      it "includes only relevant locations" do
        get "/api/testing/locations", params: { type: "gp_practice" }

        expect(response).to have_http_status(:ok)

        locations = JSON.parse(response.body)

        expect(locations).to eq([gp_practice.as_json])
      end
    end

    context "when filtering by year groups" do
      it "includes only relevant locations" do
        get "/api/testing/locations", params: { gias_year_groups: [1] }

        expect(response).to have_http_status(:ok)

        locations = JSON.parse(response.body)

        expect(locations).to contain_exactly(primary_school.as_json)
      end

      context "with multiple year groups" do
        before { create(:school, gias_year_groups: [8, 9]) }

        let!(:secondary_school) do
          create(:school, gias_year_groups: [8, 9, 10])
        end

        it "includes locations with all those year groups" do
          get "/api/testing/locations", params: { gias_year_groups: [8, 9, 10] }

          expect(response).to have_http_status(:ok)

          locations = JSON.parse(response.body)

          expect(locations).to contain_exactly(secondary_school.as_json)
        end
      end
    end

    context "when filtering by attached to team" do
      it "includes only relevant locations" do
        get "/api/testing/locations", params: { is_attached_to_team: "false" }

        expect(response).to have_http_status(:ok)

        locations = JSON.parse(response.body)

        expect(locations).to eq(
          [primary_school, secondary_school].map(&:as_json)
        )
      end
    end
  end
end
