# frozen_string_literal: true

describe AppConsentFormCardComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(consent_form) }

  let(:consent_form) do
    create(
      :consent_form,
      parent_full_name: "Jane Smith",
      parent_relationship_type: :mother,
      parent_phone: "07987 654321",
      parent_email: "jane@example.com",
      response: :refused,
      recorded_at: Time.zone.local(2024, 3, 1, 14, 23, 0),
      reason_for_refusal: "already_vaccinated",
      reason_for_refusal_notes: "Vaccinated at the GP"
    )
  end

  it { should have_text("Consent refused (online)") }
  it { should have_text("1 March 2024 at 2:23pm") }
  it { should have_text("Vaccine already received") }
  it { should have_text("Vaccinated at the GP") }

  context "when the consent form refusal reason is gelatine for flu" do
    let(:consent_form) do
      create(
        :consent_form,
        :recorded,
        :refused,
        programmes: [Programme.flu],
        reason_for_refusal: :contains_gelatine
      )
    end

    it do
      expect(rendered).to have_text(
        "Refusal reasonI’m concerned the nasal vaccine contains gelatine"
      )
    end
  end
end
