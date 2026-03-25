# frozen_string_literal: true

describe AppPatientVaccinationTableComponent do
  subject { render_inline(component) }

  let(:component) do
    described_class.new(patient, academic_year:, programme:, show_caption:)
  end

  let(:patient) { create(:patient) }
  let(:academic_year) { 2023 }
  let(:programme) { nil }
  let(:show_caption) { false }

  it { should have_content("No vaccinations") }

  context "with a vaccination record" do
    let(:location) do
      create(
        :school,
        name: "Test School",
        address_line_1: "Waterloo Road",
        address_town: "London",
        address_postcode: "SE1 8TY"
      )
    end

    let(:vaccination_record_programme) { Programme.hpv }

    let(:performed_at) { Time.zone.local(2024, 1, 1) }

    before do
      create(
        :vaccination_record,
        patient:,
        session:
          create(
            :session,
            location:,
            programmes: [vaccination_record_programme]
          ),
        programme: vaccination_record_programme,
        performed_at:
      )
    end

    it { should have_link("1 January 2024") }
    it { should have_content("Test School") }
    it { should have_content("Waterloo Road, London, SE1 8TY") }
    it { should have_content("Vaccinated") }
    it { should have_content("HPV") }

    context "when showing records from a specific programme" do
      let(:programme) { vaccination_record_programme }

      it { should_not have_content("HPV") }
    end

    context "with a vaccination record from a different programme" do
      let(:programme) { Programme.hpv }
      let(:vaccination_record_programme) { Programme.flu }

      it { should_not have_link("1 January 2024") }
      it { should_not have_content("Test School") }
      it { should_not have_content("Waterloo Road, London, SE1 8TY") }
      it { should_not have_content("Vaccinated") }
      it { should_not have_content("HPV") }
    end

    context "with a Flu vaccination record from a previous year" do
      let(:vaccination_record_programme) { Programme.flu }
      let(:programme) { vaccination_record_programme }
      let(:performed_at) { Time.zone.local(2022, 1, 1) }

      it { should_not have_link("1 January 2022") }
      it { should_not have_content("Test School") }
      it { should_not have_content("Waterloo Road, London, SE1 8TY") }
      it { should_not have_content("Vaccinated") }
      it { should_not have_content("Flu") }
    end
  end

  context "with a primary and a non-primary source NHS API record for the same programme and date" do
    let(:academic_year) { 2024 }
    let(:performed_at) { Time.zone.local(2025, 1, 15) }

    before do
      create(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        patient:,
        programme: Programme.flu,
        nhs_immunisations_api_primary_source: true,
        performed_at:
      )
      create(
        :vaccination_record,
        :sourced_from_nhs_immunisations_api,
        patient:,
        programme: Programme.flu,
        nhs_immunisations_api_primary_source: false,
        performed_at:
      )
    end

    it { should have_css("tbody tr", count: 1) }
  end
end
