# frozen_string_literal: true

describe "/api/testing/onboard" do
  before { Flipper.enable(:testing_api) }
  after { Flipper.disable(:testing_api) }

  let(:config) do
    YAML.safe_load(file_fixture(filename).read, permitted_classes: [Date])
  end

  describe "POST" do
    subject(:request) do
      post "/api/testing/onboard",
           params: config.to_json,
           headers: {
             "Content-Type" => "application/json"
           }
    end

    context "with a valid configuration file for a point of care team" do
      let(:filename) { "onboarding/point_of_care_valid.yaml" }

      before do
        Programme.hpv
        create(:gias_school, :secondary, :open, urn: "123456")
        create(:gias_school, :secondary, :open, urn: "234567")
        create(:gias_school, :secondary, :open, urn: "345678")
        create(:gias_school, :secondary, :open, urn: "456789")
      end

      it "responds with created" do
        request
        expect(response).to have_http_status(:created)
      end

      it "creates the team" do
        request
        expect(Team.count).to eq(1)
      end
    end

    context "with a valid configuration file for a national reporting team" do
      let(:filename) { "onboarding/national_reporting_valid.yaml" }

      it "responds with created" do
        request
        expect(response).to have_http_status(:created)
      end

      it "creates the team" do
        request
        expect(Team.count).to eq(1)
      end
    end

    context "with an invalid configuration file" do
      let(:filename) { "onboarding/invalid.yaml" }

      it "responds with an error" do
        request

        expect(response).to have_http_status(:unprocessable_content)

        errors = JSON.parse(response.body)

        expect(errors).to eq(
          {
            "clinics" => ["Choose at least one clinic"],
            "organisation.ods_code" => ["Enter an ODS code"],
            "team.name" => ["Enter a name"],
            "team.type" => ["Choose a type"],
            "team.workgroup" => ["Enter a workgroup"],
            "programmes" => ["Choose at least one programme"],
            "school.0.location" => ["can't be blank"],
            "school.0.status" => ["is not included in the list"],
            "school.0.subteam" => ["can't be blank"],
            "school.1.location" => ["can't be blank"],
            "school.1.status" => ["is not included in the list"],
            "school.1.subteam" => ["can't be blank"],
            "school.2.location" => ["can't be blank"],
            "school.2.status" => ["is not included in the list"],
            "school.3.location" => ["can't be blank"],
            "school.3.status" => ["is not included in the list"],
            "school.4.location" => ["can't be blank"],
            "school.4.status" => ["is not included in the list"],
            "school.5.location" => ["can't be blank"],
            "school.5.status" => ["is not included in the list"],
            "school.6.location" => ["can't be blank"],
            "school.6.status" => ["is not included in the list"],
            "school.7.location" => ["can't be blank"],
            "school.7.status" => ["is not included in the list"],
            "schools" => [
              "URN(s) 456789 cannot appear as both a regular school and a site"
            ],
            "subteam.email" => ["can't be blank"],
            "subteam.name" => ["Enter a name"]
          }
        )
      end
    end
  end
end
