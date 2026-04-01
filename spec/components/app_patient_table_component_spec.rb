# frozen_string_literal: true

describe AppPatientTableComponent do
  include Pagy::Backend

  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patients, current_user:, pagy:) }

  let(:all_patients) do
    [
      create(
        :patient,
        given_name: "John",
        family_name: "Smith",
        nhs_number: "9991000003",
        date_of_birth: Date.new(2000, 5, 28),
        address_postcode: "SW1A 1AA"
      ),
      create(
        :patient,
        :restricted,
        given_name: "Jenny",
        family_name: "Smith",
        nhs_number: "9991000011",
        date_of_birth: Date.new(2000, 5, 28),
        address_postcode: "SW1B 1AA"
      )
    ] + create_list(:patient, count - 2)
  end

  let(:pagination_result) { pagy_array(all_patients, page: 1) }
  let(:patients) { pagination_result[1] }
  let(:pagy) { pagination_result[0] }

  let(:team) { create(:team) }
  let(:current_user) { create(:nurse, team:) }

  let(:count) { 10 }

  it "renders a summary with record count" do
    expect(rendered).to have_css(
      ".nhsuk-details__summary-text",
      text: "10 imported records"
    )
  end

  it "renders the headers" do
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Name and NHS number",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Postcode",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "School",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__header",
      text: "Date of birth",
      visible: :hidden
    )
  end

  it "renders the rows" do
    expect(rendered).to have_css(
      ".nhsuk-table__body .nhsuk-table__row",
      count: 10,
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "SMITH, John",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "999 100 0003",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "28 May 2000",
      visible: :hidden
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "SW1A 1AA",
      visible: :hidden
    )
  end

  it "doesn't show postcode of restricted patients" do
    expect(rendered).not_to have_text("SW1B 1AA")
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

  context "with a patient not in the cohort" do
    it "doesn't render a link" do
      expect(rendered).not_to have_link("SMITH, John")
      expect(rendered).to have_content("Child is not in any sessions")
    end
  end

  context "with a patient is deceased" do
    before do
      patients.first.update_columns(
        date_of_death_recorded_at: Time.current,
        date_of_death: Time.current
      )
    end

    it "doesn't render a link" do
      expect(rendered).not_to have_link("SMITH, John")
      expect(rendered).to have_content("Child is deceased")
    end
  end

  context "when patient is in a different team" do
    let(:other_team) { create(:team) }
    let(:session) { create(:session, team: other_team) }

    before { create(:patient_location, patient: patients.first, session:) }

    it "doesn't render a link" do
      expect(rendered).not_to have_link("SMITH, John")
      expect(rendered).to have_content("Child is in a different SAIS team")
    end
  end

  context "with a patient in the cohort" do
    let(:session) { create(:session, team:) }

    before { create(:patient_location, patient: patients.first, session:) }

    it "renders links" do
      expect(rendered).to have_link("SMITH, John", visible: :hidden)
    end
  end
end
