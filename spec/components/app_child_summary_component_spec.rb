# frozen_string_literal: true

describe AppChildSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(patient) }

  let(:school) { create(:gias_school, name: "Test School") }
  let(:gp_practice) { nil }
  let(:other_school) { create(:gias_school, name: "Other School") }
  let(:parent) { create(:parent, full_name: "Mark Doe") }
  let(:restricted) { false }
  let(:patient) do
    create(
      :patient,
      nhs_number: "9990000018",
      given_name: "John",
      preferred_given_name: "Johnny",
      family_name: "Doe",
      date_of_birth: Date.new(2000, 1, 1),
      gender_code: "male",
      address_line_1: "10 Downing Street",
      address_postcode: "SW1A 1AA",
      school:,
      gp_practice:,
      restricted_at: restricted ? Time.current : nil,
      ethnic_group: :mixed_or_multiple_ethnic_groups,
      ethnic_background: :mixed_white_and_black_caribbean,
      pending_changes: {
        given_name: "Jane",
        date_of_birth: Date.new(2001, 1, 1),
        address_postcode: "SW1A 2AA",
        school_id: other_school.id
      }
    )
  end

  before do
    create(:parent_relationship, :father, parent:, patient:)
    patient.strict_loading!(false)
  end

  it { should have_content("NHS number") }
  it { should have_content("999 000 0018") }

  it { should have_content("Full name") }
  it { should have_content("DOE, John") }

  it { should have_content("Known as") }
  it { should have_content("DOE, Johnny") }

  it { should have_content("Date of birth") }
  it { should have_content("1 January 2000") }

  it { should have_content("Ethnicity") }

  it do
    expect(rendered).to have_content(
      "Mixed or multiple ethnic groups (White and Black Caribbean)"
    )
  end

  it { should have_content("Gender") }
  it { should have_content("Male") }

  it { should have_content("Address") }
  it { should have_content("10 Downing Street") }

  context "when the patient is restricted" do
    let(:restricted) { true }

    it { should_not have_content("Address") }
    it { should_not have_content("10 Downing Street") }
  end

  it { should have_content("School") }
  it { should have_content("Test School") }

  it { should have_content("Year group") }
  it { should have_content(/Year [0-9]+/) }

  it { should_not have_content("GP surgery") }

  context "with a GP practice" do
    let(:gp_practice) { create(:gp_practice, name: "Waterloo GP") }

    it { should have_content("GP surgery") }
    it { should have_content("Waterloo GP") }
  end

  it { should_not have_css(".app-highlight") }

  context "with pending changes" do
    let(:component) { described_class.new(patient.with_pending_changes) }

    it { should have_css(".app-highlight", text: "DOE, Jane") }
    it { should have_css(".app-highlight", text: "1 January 2001") }
    it { should have_css(".app-highlight", text: "SW1A 2AA") }
    it { should_not have_css(".app-highlight", text: "Male") }
    it { should have_css(".app-highlight", text: "Other School") }

    context "when the patient is restricted" do
      let(:restricted) { true }

      it { should_not have_content("SW1A 2AA") }
    end
  end

  context "with a consent form" do
    let(:component) { described_class.new(consent_form) }

    let(:consent_form) do
      create(:consent_form, :recorded, given_name: "John", family_name: "Doe")
    end

    it { should have_text("DOE, John") }
  end

  context "when archived" do
    let(:component) { described_class.new(patient, current_team: team) }

    let(:team) { create(:team) }

    before do
      create(
        :archive_reason,
        :other,
        patient:,
        team:,
        other_details: "Some details."
      )
    end

    it { should have_text("Archive reason") }
    it { should have_text("Other: Some details.") }
  end

  context "when archived by immunisation import" do
    let(:component) { described_class.new(patient, current_team: team) }

    let(:team) { create(:team) }

    before { create(:archive_reason, :immunisation_import, patient:, team:) }

    it { should have_text("Archive reason") }
  end

  context "when created by a national reporting upload" do
    let(:component) { described_class.new(patient, current_team: team) }

    let(:team) { create(:team, :national_reporting) }

    before { create(:archive_reason, :immunisation_import, patient:, team:) }

    it { should_not have_text("Archive reason") }
  end

  context "with a PDS lookup match" do
    let(:patient) { create(:patient) }

    before { allow(patient).to receive(:pds_lookup_match?).and_return(true) }

    it "shows a PDS history action link" do
      expect(rendered).to have_link(
        "PDS history",
        href:
          Rails.application.routes.url_helpers.pds_search_history_patient_path(
            patient
          )
      )
    end
  end

  context "without a PDS lookup match" do
    let(:patient) { create(:patient) }

    before { allow(patient).to receive(:pds_lookup_match?).and_return(false) }

    it { should_not have_link("PDS history") }

    context "when the record is not a Patient" do
      let(:consent_form) { create(:consent_form) }

      it { should_not have_link("PDS history") }
    end
  end
end
