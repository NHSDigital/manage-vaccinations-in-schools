# frozen_string_literal: true

describe AppPatientSessionPsdComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient:, session:, programme:) }

  let(:programme) { Programme.flu }
  let(:session) { create(:session, :psd_enabled, programmes: [programme]) }
  let(:patient) { create(:patient, session:) }

  context "when the session does not use PSDs" do
    let(:session) { create(:session, programmes: [programme]) }

    it "does not render" do
      expect(component.render?).to be false
    end
  end

  context "when the session uses PSDs" do
    it { should have_heading("Patient Specific Directions (PSD)") }

    context "and the patient does not have a PSD" do
      it { should have_text("PSD not added") }
    end

    context "and the patient has a PSD" do
      before do
        create(
          :patient_specific_direction,
          patient:,
          programme:,
          team: session.team,
          academic_year: session.academic_year
        )
      end

      it { should have_text("PSD added") }
    end

    context "and the patient has an invalidated PSD" do
      before do
        create(
          :patient_specific_direction,
          :invalidated,
          patient:,
          programme:,
          team: session.team,
          academic_year: session.academic_year
        )
      end

      it { should have_text("PSD not added") }
    end
  end
end
