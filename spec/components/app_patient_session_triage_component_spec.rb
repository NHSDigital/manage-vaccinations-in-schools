# frozen_string_literal: true

describe AppPatientSessionTriageComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(patient:, session:, programme:, current_user:)
  end

  let(:programme) { Programme.sample }
  let(:session) { create(:session, programmes: [programme]) }
  let(:patient) { create(:patient, session:) }
  let(:current_user) { create(:nurse) }

  before { stub_authorization(allowed: true) }

  context "without triage" do
    it { should_not have_link("Update triage outcome") }
  end

  context "when consent is given and triage is not needed" do
    let(:programme) { Programme.hpv }
    let(:patient) do
      create(:patient, :consent_given_triage_not_needed, session:)
    end

    it { should have_link("Update triage outcome") }
  end

  context "when triaged as safe to vaccinate" do
    before { create(:triage, :safe_to_vaccinate, patient:, programme:) }

    it { should have_content("safe to vaccinate") }
    it { should have_link("Update triage outcome") }
  end

  context "when triaged as unsafe to vaccinate" do
    before { create(:triage, :do_not_vaccinate, patient:, programme:) }

    it { should have_content("should not be vaccinated") }
    it { should have_link("Update triage outcome") }
  end
end
