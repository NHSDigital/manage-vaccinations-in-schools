# frozen_string_literal: true

describe AppPatientProgrammesTableComponent do
  include Rails.application.routes.url_helpers

  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(patient, current_team: team, programmes:)
  end
  let(:team) { create(:team, programmes:) }
  let(:session) { create(:session, team:, programmes:) }
  let(:nurse) do
    create(:user, :nurse, given_name: "Jane", family_name: "Smith")
  end

  let(:today) { Date.new(2025, 9, 1) }

  around { |example| travel_to(today) { example.run } }

  context "for seasonal programmes" do
    let(:patient) { create(:patient, session:) }
    let(:programmes) { [Programme.flu] }

    it "has the correct column headings" do
      expect(rendered).to have_css(".nhsuk-table__header", text: "Programme")
      expect(rendered).to have_css(".nhsuk-table__header", text: "Status")
      expect(rendered).to have_css(".nhsuk-table__header", text: "Notes")
    end

    it { should have_content("Vaccination programmes") }

    it "renders a link to the Flu tab" do
      expect(rendered).to have_link(
        "Flu (winter 2025)",
        href: patient_programme_path(patient, "flu")
      )
    end

    it { should_not have_content("Vaccinated") }

    context "when vaccinated" do
      let(:patient) { create(:patient, :vaccinated, session:) }

      it { should have_content("Vaccinated") }
    end

    context "when vaccinated last year" do
      let(:patient) { create(:patient, session:, parents: [create(:parent)]) }

      before do
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          performed_at: Time.zone.local(2024, 9, 1)
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should have_content("Flu (winter 2025)Needs consent") }
      it { should have_content("Flu (winter 2024)Vaccinated") }
    end

    context "when consent refused" do
      let(:patient) { create(:patient, :consent_refused, session:) }

      before { PatientStatusUpdater.call(patient:) }

      it { should have_content("Has a refusal") }
      it { should have_content("Consent refused") }
    end

    context "when triage outcome was 'Do not vaccinate'" do
      let(:patient) do
        create(
          :patient,
          :consent_given_triage_needed,
          :triage_do_not_vaccinate,
          session:
        )
      end

      it { should have_content("Unable to vaccinateContraindications") }
    end

    context "when no outcome yet but had contraindications" do
      let(:patient) { create(:patient, session:) }

      before do
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          outcome: :contraindicated,
          performed_at: today,
          session:
        )
        PatientStatusUpdater.call(patient:)
      end

      it do
        expect(rendered).to have_content(
          "Child contraindicated on #{today.to_fs(:long)}"
        )
      end
    end

    context "when no outcome yet but was unwell" do
      let(:patient) { create(:patient, session:) }

      before do
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          outcome: :unwell,
          performed_at: today,
          session:
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should have_content("Unable to vaccinate") }
      it { should have_content("Child unwell on #{today.to_fs(:long)}") }
    end

    context "when no outcome yet but refused vaccine" do
      let(:patient) { create(:patient, session:) }

      before do
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          outcome: :refused,
          performed_at: today,
          session:
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should have_content("Unable to vaccinate") }
      it { should have_content("Child refused on #{today.to_fs(:long)}") }
    end
  end

  context "for non-seasonal programmes" do
    let(:patient) { create(:patient, session:, year_group: 8) }
    let(:programmes) { [Programme.hpv, Programme.menacwy, Programme.td_ipv] }

    it { should have_content("Vaccination programmes") }
    it { should have_link("HPV", href: patient_programme_path(patient, "hpv")) }

    it "renders a link to the Td/IPV tab" do
      expect(rendered).to have_link(
        "Td/IPV",
        href: patient_programme_path(patient, "td_ipv")
      )
    end

    it "renders a link to the MenACWY tab" do
      expect(rendered).to have_link(
        "MenACWY",
        href: patient_programme_path(patient, "menacwy")
      )
    end

    context "when vaccinated last year" do
      let(:patient) { create(:patient, session:) }

      before do
        create(
          :vaccination_record,
          patient:,
          programme: programmes.first,
          performed_at: Time.zone.local(2024, 9, 1)
        )
        PatientStatusUpdater.call(patient:)
      end

      it { should have_content("Vaccinated") }
    end
  end
end
