# frozen_string_literal: true

describe AppGillickAssessmentComponent do
  subject(:rendered) { render_inline(component) }

  let(:programme) { Programme.hpv }
  let(:component) { described_class.new(patient:, session:, programme:) }
  let(:patient) { create(:patient) }
  let(:session) { create(:session, :today, programmes: [programme]) }

  before { stub_authorization(allowed: true) }

  context "without a Gillick assessment" do
    it { should have_link("Assess Gillick competence") }
    it { should have_heading("Gillick assessment") }
  end

  context "with a competent Gillick assessment" do
    before { create(:gillick_assessment, :competent, patient:, session:) }

    it { should have_text("Child assessed as Gillick competent") }
    it { should have_link("Update Gillick competence") }
    it { should have_heading("Gillick assessment") }

    context "with an admin user" do
      before { stub_authorization(allowed: false) }

      it { should_not have_link("Update Gillick competence") }
    end
  end

  context "with a not-competent Gillick assessment" do
    before { create(:gillick_assessment, :not_competent, patient:, session:) }

    it { should have_text("Child assessed as not Gillick competent") }
    it { should have_link("Update Gillick competence") }
  end

  context "when the session is not today" do
    let(:session) { create(:session, :scheduled, programmes: [programme]) }

    it { should_not have_heading("Gillick assessment") }
    it { should_not have_link("Assess Gillick competence") }
  end
end
