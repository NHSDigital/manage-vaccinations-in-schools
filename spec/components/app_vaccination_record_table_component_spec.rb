# frozen_string_literal: true

describe AppVaccinationRecordTableComponent do
  include Pagy::Backend

  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(vaccination_records, current_user:, pagy:)
  end

  let(:programme) { Programme.sample }
  let(:all_vaccination_records) do
    [
      create(
        :vaccination_record,
        programme:,
        performed_at: Time.zone.local(2020, 9, 1),
        patient:
          create(
            :patient,
            given_name: "John",
            family_name: "Smith",
            nhs_number: "9999999999",
            date_of_birth: Date.new(2000, 5, 28),
            address_postcode: "SW1A 2AA"
          ),
        session:
          create(:session, programmes: [programme], date: Date.new(2020, 9, 1))
      )
    ] + create_list(:vaccination_record, 4, programme:) +
      create_list(:vaccination_record, count - 5, :not_administered, programme:)
  end
  let(:count) { 10 }

  let(:pagination_result) { pagy_array(all_vaccination_records, page: 1) }
  let(:vaccination_records) { pagination_result[1] }
  let(:pagy) { pagination_result[0] }

  let(:current_user) { create(:nurse) }

  it "renders a summary with record count" do
    expect(rendered).to have_css(
      ".nhsuk-details__summary-text",
      text: "10 imported records"
    )
  end

  it "renders the headers" do
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Full name",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "NHS number",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Date of birth",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Vaccination date",
      visible: :hidden
    )
  end

  it "renders the rows" do
    expect(rendered).to have_css(
      ".nhsuk-table__body .nhsuk-table__row",
      count: count,
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "SMITH, John",
      visible: :hidden
    )
    expect(rendered).to have_link("SMITH, John", visible: :hidden)
    expect(rendered).to have_css(
      ".nhsuk-table__cell .nhsuk-u-nowrap",
      text: "999 999 9999",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "28 May 2000",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "1 September 2020",
      visible: :hidden
    )
  end

  it "does not render pagination summary text" do
    expect(rendered).not_to have_content("showing 1 to 10")
  end

  context "with paginated results" do
    let(:count) { 55 }

    it "renders 50 rows of data" do
      expect(rendered).to have_css(
        ".nhsuk-table__body .nhsuk-table__row",
        count: 50,
        visible: :hidden
      )
    end

    it "renders pagination summary text" do
      expect(rendered).to have_content("showing 1 to 50")
    end
  end

  context "with a vaccination record not performed by the team" do
    before do
      vaccination_records.first.patient.patient_locations.destroy_all
      vaccination_records.first.update!(
        session: nil,
        source: "historical_upload",
        location: nil,
        location_name: "Unknown",
        performed_ods_code: nil
      )
    end

    it { should_not have_link("SMITH, John") }
  end
end
