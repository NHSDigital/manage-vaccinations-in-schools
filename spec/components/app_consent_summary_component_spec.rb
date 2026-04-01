# frozen_string_literal: true

describe AppConsentSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(consent) }

  let(:consent) { create(:consent) }

  it { should_not have_content("Programme") }

  context "when showing the programme" do
    let(:component) { described_class.new(consent, show_programme: true) }

    it { should have_content("Programme") }
  end

  it { should_not have_content("Method") }

  context "when showing the route" do
    let(:component) { described_class.new(consent, show_route: true) }

    it { should have_content("Method") }
  end

  it { should have_content("Response") }

  context "when recorded" do
    let(:consent) { create(:consent) }

    it { should have_content("Date") }
  end

  context "when refused" do
    let(:consent) { create(:consent, :refused) }

    it { should have_content("Reason for refusal") }
  end

  context "when withdrawn" do
    let(:consent) { create(:consent, :withdrawn) }

    it { should have_content("Consent givenWithdrawn") }
  end

  context "with notes" do
    let(:consent) { create(:consent, :refused, notes: "Some notes.") }

    it { should_not have_content("Notes") }

    context "when showing the notes" do
      let(:component) { described_class.new(consent, show_notes: true) }

      it { should have_content("NotesSome notes.") }
    end
  end

  it { should_not have_content("Confirmation of vaccination sent to parent?") }

  context "when the child doesn't want the parents to know about the vaccination" do
    let(:consent) { create(:consent, :given, :self_consent) }
    let(:component) { described_class.new(consent, show_notify_parent: true) }

    it do
      expect(rendered).to have_content(
        "Confirmation of vaccination sent to parent?No"
      )
    end
  end

  context "when the child wants the parents to know about the vaccination" do
    let(:consent) do
      create(:consent, :given, :self_consent, :notify_parents_on_vaccination)
    end
    let(:component) { described_class.new(consent, show_notify_parent: true) }

    it do
      expect(rendered).to have_content(
        "Confirmation of vaccination sent to parent?Yes"
      )
    end
  end

  it { should_not have_content("Consent also given for injected vaccine?") }

  context "with the flu programme" do
    let(:programme) { Programme.flu }
    let(:consent) { create(:consent, programme:, vaccine_methods: %w[nasal]) }

    it { should have_content("ResponseConsent given") }
    it { should have_content("Chosen vaccineNasal spray only") }

    context "and consenting to multiple vaccine methods" do
      let(:consent) do
        create(:consent, programme:, vaccine_methods: %w[nasal injection])
      end

      it { should have_content("ResponseConsent given") }

      it do
        expect(rendered).to have_content(
          "Chosen vaccineNasal spray or injected vaccine"
        )
      end
    end

    context "when refused" do
      let(:consent) { create(:consent, :refused, programme:) }

      it { should_not have_content("Chosen vaccine") }
    end

    context "when no response" do
      let(:consent) { create(:consent, :not_provided, programme:) }

      it { should_not have_content("Chosen vaccine") }
    end
  end

  context "when refused for flu due to gelatine" do
    let(:programme) { Programme.flu }
    let(:consent) do
      create(
        :consent,
        :refused,
        programme:,
        reason_for_refusal: "contains_gelatine"
      )
    end

    it "shows the flu-specific gelatine copy" do
      expect(rendered).to have_content(
        "Reason for refusalI’m concerned the nasal vaccine contains gelatine"
      )
    end
  end

  context "when refused for MMR due to gelatine" do
    let(:programme) do
      Programme::Variant.new(Programme.mmr, variant_type: "mmr")
    end
    let(:consent) do
      create(
        :consent,
        :refused,
        programme:,
        reason_for_refusal: "contains_gelatine"
      )
    end

    it "shows the MMR-specific gelatine copy" do
      expect(rendered).to have_content(
        "I’m concerned the vaccine contains gelatine"
      )
    end
  end

  context "with the MMR programme" do
    let(:programme) { Programme.mmr }
    let(:consent) do
      create(:consent, programme:, vaccine_methods: %w[injection])
    end

    it do
      expect(rendered).to have_content(
        "Gelatine-free injected vaccine or injected vaccine"
      )
    end
  end

  context "when showing parent's name" do
    let(:component) { described_class.new(consent, show_parent_name: true) }

    it { should have_content("Parent#{consent.parent.full_name}") }
  end

  context "when showing email and phone" do
    let(:parent) do
      create(:parent, email: "parent@example.com", phone: "07700900123")
    end
    let(:consent) do
      create(
        :consent,
        parent:,
        parent_email: "stored@example.com",
        parent_phone: "07700900456"
      )
    end
    let(:component) do
      described_class.new(
        consent,
        show_email_address: true,
        show_phone_number: true
      )
    end

    it "uses stored parent details" do
      expect(rendered).to have_content("stored@example.com")
      expect(rendered).to have_content("07700 900456")
      expect(rendered).not_to have_content("parent@example.com")
      expect(rendered).not_to have_content("07700 900123")
    end
  end

  context "when showing email and phone without stored details (legacy consent)" do
    let(:parent) do
      create(:parent, email: "parent@example.com", phone: "07700900123")
    end
    let(:consent) do
      create(:consent, parent:, parent_email: nil, parent_phone: nil)
    end
    let(:component) do
      described_class.new(
        consent,
        show_email_address: true,
        show_phone_number: true
      )
    end

    it "falls back to parent object details" do
      expect(rendered).to have_content("parent@example.com")
      expect(rendered).to have_content("07700 900123")
    end
  end
end
