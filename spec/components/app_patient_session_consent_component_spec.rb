# frozen_string_literal: true

describe AppPatientSessionConsentComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:, programme:) }

  let(:programme) { Programme.hpv }
  let(:session) { create(:session, programmes: [programme]) }
  let(:patient) { create(:patient, session:, parents: [create(:parent)]) }

  before { stub_authorization(allowed: true) }

  context "without consent" do
    it { should_not have_content(/Consent (given|refused)/) }
    it { should_not have_css("details", text: /Consent (given|refused) by/) }
    it { should_not have_css("details", text: "Responses to health questions") }
    it { should have_css("p", text: "No requests have been sent.") }
    it { should have_link("Record a new consent response") }

    context "when session is not in progress" do
      let(:session) { create(:session, :scheduled, programmes: [programme]) }

      it { should_not have_css("button", text: "Assess Gillick competence") }
    end
  end

  context "when vaccinated" do
    before do
      create(:patient_programme_status, :vaccinated_fully, patient:, programme:)
    end

    it { should_not have_css("p", text: "No requests have been sent.") }
    it { should_not have_link("Record a new consent response") }
    it { should_not have_css("button", text: "Assess Gillick competence") }
  end

  context "with refused consent" do
    let(:parent) { create(:parent_relationship, :mother, patient:).parent }
    let!(:consent) do
      create(:consent, :refused, patient: patient.reload, parent:, programme:)
    end

    it { should have_content("refused to give consent") }
    it { should have_content(consent.parent.full_name) }
    it { should have_content(consent.parent_relationship.label) }
    it { should have_content("Consent refused") }
    it { should_not have_css("details", text: "Responses to health questions") }
  end

  context "with given consent" do
    let(:patient) do
      create(:patient, :consent_given_triage_not_needed, session:)
    end

    let(:consent) { patient.consents.first }

    it { should have_text("is ready for the vaccinator") }

    it { should_not have_css("a", text: "Contact #{consent.parent.full_name}") }

    context "and the programme is flu" do
      let(:programme) { Programme.flu }

      let(:patient) do
        create(:patient, :consent_given_nasal_only_triage_not_needed, session:)
      end

      it { should have_text("Nasal spray only") }

      context "and the vaccine method is overridden by triage" do
        let(:patient) do
          create(
            :patient,
            :consent_given_injection_and_nasal_triage_safe_to_vaccinate_injection,
            session:
          )
        end

        it { should have_text("is ready for the vaccinator") }
      end
    end
  end
end
