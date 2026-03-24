# frozen_string_literal: true

describe AppPatientSearchResultCardComponent do
  subject { render_inline(component) }

  let(:patient) do
    create(
      :patient,
      address_postcode: "SW11 1AA",
      date_of_birth: Date.new(2020, 1, 1),
      family_name: "Seldon",
      given_name: "Hari",
      nhs_number: "9000000009",
      school: build(:gias_school, name: "Streeling University")
    )
  end

  let(:link_to) { "/patient" }
  let(:current_team) { create(:team) }
  let(:programmes) { [] }
  let(:academic_year) { nil }
  let(:show_clinic_invitations) { false }
  let(:show_nhs_number) { false }
  let(:show_postcode) { false }
  let(:show_school) { false }

  let(:component) do
    described_class.new(
      patient,
      link_to:,
      current_team:,
      programmes:,
      academic_year:,
      show_clinic_invitations:,
      show_nhs_number:,
      show_postcode:,
      show_school:
    )
  end

  it { should have_link("SELDON, Hari", href: "/patient") }
  it { should have_text("1 January 2020") }
  it { should_not have_text("900 000 0009") }
  it { should_not have_text("SW11 1AA") }
  it { should_not have_text("Streeling University") }
  it { should_not have_text("Clinic invitations") }

  context "when showing the NHS number" do
    let(:show_nhs_number) { true }

    it { should have_text("900 000 0009") }
  end

  context "when showing the postcode" do
    let(:show_postcode) { true }

    it { should have_text("SW11 1AA") }
  end

  context "when showing the school" do
    let(:show_school) { true }

    it { should have_text("Streeling University") }
  end

  context "with the flu programme" do
    let(:programme) { Programme.flu }
    let(:programmes) { [programme] }

    it { should have_text("Programme statusFluNot eligible") }

    context "with a session status of unwell" do
      before do
        create(
          :patient_programme_status,
          :cannot_vaccinate_unwell,
          patient:,
          programme:
        )
      end

      it { should have_text("FluUnable to vaccinateChild unwell") }
    end
  end

  context "with the MMR(V) programme" do
    let(:programme) { Programme.mmr }
    let(:programmes) { [programme] }

    context "with a patient not eligible for MMRV" do
      let(:patient) { create(:patient, date_of_birth: Date.new(2019, 1, 1)) }

      it { should have_text("Programme statusMMR") }
      it { should_not have_text("MMRV") }
    end

    context "with a patient eligible for MMRV" do
      let(:patient) { create(:patient, date_of_birth: Date.new(2020, 1, 1)) }

      it { should have_text("Programme statusMMRV") }
    end
  end

  context "when showing clinic invitations" do
    let(:show_clinic_invitations) { true }
    let(:academic_year) { AcademicYear.current }

    context "with no clinic notifications" do
      it { should_not have_text("Clinic invitations") }
    end

    context "with a clinic notification for one programme" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team: current_team,
          academic_year:,
          programmes: [Programme.flu]
        )
      end

      it { should have_text("Clinic invitations") }
      it { should have_text("Flu") }
    end

    context "with clinic notifications for multiple programmes" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team: current_team,
          academic_year:,
          programmes: [Programme.flu]
        )
        create(
          :clinic_notification,
          :subsequent_invitation,
          patient:,
          team: current_team,
          academic_year:,
          programmes: [Programme.hpv]
        )
      end

      it { should have_text("Clinic invitations") }
      it { should have_text("Flu") }
      it { should have_text("HPV") }
    end

    context "with duplicate programme notifications" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team: current_team,
          academic_year:,
          programmes: [Programme.flu]
        )
        create(
          :clinic_notification,
          :subsequent_invitation,
          patient:,
          team: current_team,
          academic_year:,
          programmes: [Programme.flu]
        )
      end

      it { should have_text("Clinic invitations") }
      it { should have_text("Flu") }
      it { should have_css(".nhsuk-tag", count: 1) }
    end

    context "with clinic notifications for a different team" do
      let(:other_team) { create(:team) }

      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team: other_team,
          academic_year:,
          programmes: [Programme.flu]
        )
      end

      it { should_not have_text("Clinic invitations") }
    end

    context "with clinic notifications for a different academic year" do
      before do
        create(
          :clinic_notification,
          :initial_invitation,
          patient:,
          team: current_team,
          academic_year: AcademicYear.previous,
          programmes: [Programme.flu]
        )
      end

      it { should_not have_text("Clinic invitations") }
    end
  end
end
