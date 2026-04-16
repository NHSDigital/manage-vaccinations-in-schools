# frozen_string_literal: true

describe AppPatientSessionSearchResultCardComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(patient:, session:, programmes:, return_to:)
  end

  let(:patient) do
    create(
      :patient,
      given_name: "Hari",
      family_name: "Seldon",
      address_postcode: "SW11 1AA",
      year_group: 8,
      school: build(:gias_school, name: "Streeling University"),
      session:
    )
  end

  let(:programme) { Programme.hpv }
  let(:programmes) { [programme] }
  let(:session) { create(:session, programmes:) }
  let(:return_to) { :patients }

  let(:href) do
    "/sessions/#{session.slug}/patients/#{patient.id}/hpv?return_to=patients"
  end

  before { patient.strict_loading!(false) }

  it { should have_link("SELDON, Hari", href:) }
  it { should have_text("Year 8") }
  it { should_not have_text("Consent status") }
  it { should_not have_text("Vaccine type") }

  context "when showing notes" do
    let(:component) do
      described_class.new(patient:, session:, programmes:, show_notes: true)
    end

    context "and there's a note" do
      let(:note) { create(:note, patient:, session:) }

      it { should have_text(note.body) }
      it { should_not have_link("Continue reading") }
    end

    context "and there's a long note" do
      before { create(:note, patient:, session:, body: "a long note " * 50) }

      it do
        expect(rendered).to have_text(
          "a long note a long note a long note a long note a long note a long note " \
            "a long note a long note a long note a long note a long note a long note " \
            "a long note a long note a long note a long note a long note a long note " \
            "a long note a long note a long note a long note a long note a long note " \
            "a long note a long note a long…"
        )
      end

      it { should have_link("Continue reading") }
    end

    context "and there is a note from a different session" do
      let(:other_session) { create(:session, programmes: [programme]) }
      let(:note) { create(:note, patient:, session: other_session) }

      it { should_not have_text(note.body) }
      it { should_not have_link("Continue reading") }
    end
  end

  context "when showing the patient specific direction status" do
    let(:component) do
      described_class.new(
        patient:,
        session:,
        programmes:,
        show_patient_specific_direction_status: true
      )
    end

    let(:programme) { Programme.flu }

    it { should have_text("PSD statusPSD not added") }

    context "with a PSD" do
      before { create(:patient_specific_direction, patient:, programme:) }

      it { should have_text("PSD statusPSD added") }
    end

    context "with an invalidated PSD" do
      before do
        create(:patient_specific_direction, :invalidated, patient:, programme:)
      end

      it { should have_text("PSD statusPSD not added") }
    end
  end

  context "when showing the registration status" do
    let(:component) do
      described_class.new(
        patient:,
        session:,
        programmes:,
        show_registration_status: true
      )
    end

    context "when allowed to record attendance" do
      before { stub_authorization(allowed: true) }

      it { should have_text("Registration status") }
      it { should have_button("Attending") }
      it { should have_button("Absent") }
    end

    context "when not allowed to record attendance" do
      before { stub_authorization(allowed: false) }

      it { should have_text("Registration status") }
      it { should_not have_button("Attending") }
      it { should_not have_button("Absent") }
    end
  end

  context "when showing the programme status" do
    let(:component) do
      described_class.new(
        patient:,
        session:,
        programmes:,
        show_programme_status: true
      )
    end

    it { should have_text("Programme status") }

    context "and the programme is flu" do
      let(:programme) { Programme.flu }

      it { should_not have_text("Vaccine type") }
    end
  end

  context "when not showing the programme status" do
    let(:component) do
      described_class.new(
        patient:,
        session:,
        programmes:,
        show_programme_status: false
      )
    end

    it { should_not have_text("Programme status") }
  end

  context "when showing the vaccine type" do
    let(:component) do
      described_class.new(
        patient:,
        session:,
        programmes:,
        show_vaccine_type: true
      )
    end

    it { should_not have_text("Vaccine type") }

    context "and the programme is flu" do
      let(:programme) { Programme.flu }
      let(:academic_year) { AcademicYear.current }

      let(:patient) do
        create(
          :patient,
          :consent_given_injection_and_nasal_triage_safe_to_vaccinate_nasal,
          session:
        )
      end

      it { should have_text("Vaccine type") }
      it { should have_text("Nasal") }

      context "and once vaccinated" do
        before do
          create(:vaccination_record, patient:, programme:, session:)
          PatientStatusUpdater.call(patient:)
          patient.reload
        end

        it { should_not have_text("Vaccine type") }
      end
    end
  end
end
