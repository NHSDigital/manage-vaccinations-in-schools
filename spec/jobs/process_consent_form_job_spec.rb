# frozen_string_literal: true

describe ProcessConsentFormJob, :pds do
  subject(:perform) { described_class.new.perform(consent_form.id) }

  let(:team) { create(:team) }
  let(:session) { create(:session, team:) }
  let(:consent_form) do
    create(
      :consent_form,
      :recorded,
      session:,
      given_name: "John",
      family_name: "Smith",
      date_of_birth: Date.new(2010, 1, 1),
      address_postcode: "SW11 1AA"
    )
  end

  let!(:stub) do
    stub_request(
      :get,
      "https://sandbox.api.service.nhs.uk/personal-demographics/FHIR/R4/Patient"
    ).with(query: hash_including({})).to_return(
      body: file_fixture(response_file),
      headers: {
        "Content-Type" => "application/fhir+json"
      }
    )
  end

  context "with no matching patients" do
    let(:response_file) { "pds/search-patients-no-results-response.json" }

    it_behaves_like "a method that updates team cached counts"

    it "doesn't create a consent" do
      expect { perform }.not_to change(Consent, :count)
    end

    it "makes requests to PDS" do
      perform
      expect(stub).to have_been_requested.twice
    end
  end

  context "with a consent form that's already been matched" do
    let(:response_file) { "pds/search-patients-no-results-response.json" }

    before do
      create(:consent, programme: session.programmes.first, consent_form:)
    end

    it "doesn't create a consent" do
      expect { perform }.not_to change(Consent, :count)
    end

    it "doesn't make a request to PDS" do
      perform
      expect(stub).not_to have_been_requested
    end
  end

  context "with one matching patient" do
    let(:response_file) { "pds/search-patients-no-results-response.json" }
    let!(:patient) do
      create(
        :patient,
        given_name: "John",
        family_name: "Smith",
        date_of_birth: Date.new(2010, 1, 1),
        session:,
        parents: []
      )
    end

    it_behaves_like "a method that updates team cached counts"

    it "creates a consent" do
      expect { perform }.to change(Consent, :count).by(1)
    end

    it "creates a parent" do
      expect { perform }.to change(Parent, :count).by(1)
    end

    it "creates a parent relationship" do
      expect { perform }.to change(ParentRelationship, :count).by(1)

      expect(ParentRelationship.first).to have_attributes(
        patient:,
        parent: Parent.first
      )
    end

    context "when the case isn't the same" do
      let(:consent_form) do
        create(
          :consent_form,
          :recorded,
          session:,
          given_name: "john",
          family_name: "SMITH",
          date_of_birth: Date.new(2010, 1, 1)
        )
      end

      it "still matches successfully" do
        expect { perform }.to change(Consent, :count).by(1)
      end
    end
  end

  context "with multiple matching patients" do
    let(:response_file) { "pds/search-patients-no-results-response.json" }

    before do
      create_list(
        :patient,
        2,
        given_name: consent_form.given_name,
        family_name: consent_form.family_name,
        date_of_birth: consent_form.date_of_birth,
        session:
      )
    end

    it "doesn't create a consent" do
      expect { perform }.not_to change(Consent, :count)
    end
  end

  context "with a successful NHS number lookup" do
    let(:response_file) { "pds/search-patients-response.json" }
    let(:nhs_number) { "9449306168" }

    before { create(:gp_practice, ods_code: "H81109") }

    context "when the patient with the NHS number exists" do
      let!(:patient) { create(:patient, nhs_number:, session:) }

      it "creates a consent" do
        expect { perform }.to change(Consent, :count).by(1)
        expect(Consent.first.patient).to eq(patient)
      end
    end

    context "when the patient with the NHS number doesn't exist" do
      it "doesn't create a consent" do
        expect { perform }.not_to change(Consent, :count)
      end

      it "updates the consent form with the NHS number" do
        expect { perform }.to change { consent_form.reload.nhs_number }.to(
          nhs_number
        )
      end
    end

    context "when a patient with no NHS number but matching details exists" do
      before do
        create(
          :patient,
          nhs_number: nil,
          given_name: consent_form.given_name,
          family_name: consent_form.family_name,
          date_of_birth: consent_form.date_of_birth
        )
      end

      it "doesn't create a consent" do
        expect { perform }.not_to change(Consent, :count)
      end

      it "doesn't update the consent form with the NHS number" do
        expect { perform }.not_to(change { consent_form.reload.nhs_number })
      end
    end
  end
end
