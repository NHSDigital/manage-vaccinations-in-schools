# frozen_string_literal: true

describe ConsentFormsController do
  let(:programme) { Programme.hpv }
  let(:team) { create(:team, programmes: [programme]) }
  let(:user) { create(:user, :nurse, team:) }
  let(:location) { create(:gias_school, team:, programmes: [programme]) }
  let(:session) { create(:session, team:, location:, programmes: [programme]) }

  before { sign_in user }

  describe "PATCH #update_match" do
    subject do
      patch :update_match,
            params: {
              id: consent_form.id,
              patient_id: patient.id
            }
    end

    let(:consent_form) do
      create(
        :consent_form,
        :recorded,
        session:,
        given_name: "John",
        family_name: "Smith",
        date_of_birth: Date.new(2010, 1, 1)
      )
    end

    let(:patient) do
      create(
        :patient,
        given_name: "John",
        family_name: "Smith",
        date_of_birth: Date.new(2010, 1, 1),
        session:
      )
    end

    it_behaves_like "a method that updates team cached counts"
  end

  describe "POST #create_patient" do
    subject { post :create_patient, params: { id: consent_form.id } }

    let(:consent_form) do
      create(
        :consent_form,
        :recorded,
        session:,
        given_name: "Jane",
        family_name: "Doe",
        date_of_birth: Date.new(2010, 5, 15),
        address_line_1: "123 Test St",
        address_town: "Testville",
        address_postcode: "TE1 1ST"
      )
    end

    it_behaves_like "a method that updates team cached counts"
  end
end
