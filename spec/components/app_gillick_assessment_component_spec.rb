# frozen_string_literal: true

describe AppGillickAssessmentComponent do
  let(:programmes) { [Programme.hpv] }

  let(:component) do
    described_class.new(patient:, session:, programme: programmes.first)
  end

  before { stub_authorization(allowed: true) }

  describe "rendered component" do
    subject { render_inline(component) }

    let(:patient) { create(:patient) }
    let(:session) { create(:session, :today, programmes:) }

    let(:date) { Date.current }

    before do
      create(:gillick_assessment, :competent, patient:, session:, date:)
    end

    context "with a nurse user" do
      before { stub_authorization(allowed: true) }

      it { should have_heading("Gillick assessment") }
      it { should have_link("Edit Gillick competence") }
      it { should have_content("Child assessed as Gillick competent") }

      context "when the assessment is for a different day" do
        let(:date) { Date.yesterday }

        it { should have_link("Assess Gillick competence") }
        it { should_not have_content("Child assessed as Gillick competent") }
      end
    end

    context "with an admin user" do
      before { stub_authorization(allowed: false) }

      it { should_not have_link("Edit Gillick competence") }
    end
  end
end
