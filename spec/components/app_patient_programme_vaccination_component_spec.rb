# frozen_string_literal: true

describe AppPatientProgrammeVaccinationComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient, programme, academic_year:) }

  let(:patient) { create(:patient) }
  let(:academic_year) { 2023 }
  let(:programme) { Programme.hpv }

  it { should have_css(".nhsuk-card__heading", text: "No vaccination record") }
  it { should_not have_css(".nhsuk-table") }

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

    it { should have_css(".nhsuk-card__heading", text: "Vaccination record") }

    it { should have_css(".nhsuk-tag", text: "Not eligible") }
    it { should have_css(".nhsuk-table__header", text: "Vaccination date") }
    it { should have_link("1 January 2024") }

    it do
      expect(rendered).to have_css(
        ".nhsuk-table",
        text: /Age\s+#{patient.age_years(now: performed_at)} years/
      )
    end

    it { should have_css(".nhsuk-table", text: /Programme\s+HPV/) }
    it { should have_css(".nhsuk-table", text: /Source\s+Recorded in Mavis/) }
    it { should have_css(".nhsuk-table", text: /Outcome\s+Vaccinated/) }

    context "with a vaccination record from a different programme" do
      let(:programme) { Programme.hpv }
      let(:vaccination_record_programme) { Programme.flu }

      it { should_not have_link("1 January 2024") }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-table",
          text: "#{patient.age_years(now: performed_at)} years"
        )
      end

      it { should_not have_css(".nhsuk-table", text: "HPV") }
      it { should_not have_css(".nhsuk-table", text: "Recorded in Mavis") }
    end

    context "with a Flu vaccination record from a previous year" do
      let(:vaccination_record_programme) { Programme.flu }
      let(:programme) { vaccination_record_programme }
      let(:performed_at) { Time.zone.local(2022, 1, 1) }

      it { should_not have_link("1 January 2022") }

      it do
        expect(rendered).not_to have_css(
          ".nhsuk-table",
          text: "#{patient.age_years(now: performed_at)} years"
        )
      end

      it { should_not have_css(".nhsuk-table", text: "Flu") }
      it { should_not have_css(".nhsuk-table", text: "Recorded in Mavis") }
    end
  end
end
