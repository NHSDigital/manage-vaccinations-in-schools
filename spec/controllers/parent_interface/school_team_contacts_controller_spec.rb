# frozen_string_literal: true

describe ParentInterface::SchoolTeamContactsController do
  describe "GET #show" do
    subject(:request) { get :show, params: }

    context "when on contact_details step and the school does not exist" do
      let(:params) { { id: "contact-details" } }

      before do
        session["school_team_contact"] = { "school_id" => 0 }
      end

      it "returns an error" do
        expect { request }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when on contact_details step and the school does not have any team" do
      let(:school) { create(:school) }
      let(:params) { { id: "contact-details" } }

      before do
        TeamLocation.where(location: school).destroy_all
        session["school_team_contact"] = { "school_id" => school.id }
      end

      it "returns an error" do
        expect { request }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
