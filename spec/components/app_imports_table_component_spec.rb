# frozen_string_literal: true

describe AppImportsTableComponent do
  include Pagy::Backend

  subject(:rendered) { render_inline(component) }

  let(:component) do
    described_class.new(team:, uploaded_files:, mixnmatch_imports:, pagy:)
  end

  let(:programmes) { [Programme.sample] }
  let(:team) { create(:team, programmes:) }
  let(:school) { create(:gias_school, team:, name: "Test School") }
  let(:session) { create(:session, programmes:, location: school) }
  let(:uploaded_files) { false }
  let(:mixnmatch_imports) do
    CohortImport
      .select(:id, :created_at, "'CohortImport' as model_name")
      .union(
        ClassImport.select(:id, :created_at, "'ClassImport' as model_name")
      )
      .union(
        ImmunisationImport.select(
          :id,
          :created_at,
          "'ImmunisationImport' as model_name"
        )
      )
  end
  let(:pagination_result) { pagy_array(all_import_records, page: 1) }
  let(:all_import_records) do
    CohortImport.all + ClassImport.all + ImmunisationImport.all
  end
  let(:pagy) { pagination_result[0] }

  before do
    cohort_imports =
      [
        create(
          :cohort_import,
          :processed,
          team:,
          created_at: Date.new(2020, 1, 1),
          uploaded_by:
            create(:user, given_name: "Jennifer", family_name: "Smith")
        )
      ] + create_list(:cohort_import, 4, :processed, team:)

    cohort_imports.each do |cohort_import|
      create(:patient, cohort_imports: [cohort_import])
    end

    immunisation_imports =
      [
        create(
          :immunisation_import,
          :processed,
          team:,
          created_at: Date.new(2020, 1, 1),
          uploaded_by: create(:user, given_name: "John", family_name: "Smith")
        )
      ] + create_list(:immunisation_import, 4, :processed, team:)

    immunisation_imports.each do |immunisation_import|
      create(
        :vaccination_record,
        team:,
        programme: programmes.first,
        immunisation_imports: [immunisation_import]
      )
    end

    create(
      :class_import,
      :processed,
      team:,
      created_at: Date.new(2020, 1, 1),
      uploaded_by: create(:user, given_name: "Jack", family_name: "Smith"),
      session:
    )
  end

  it "renders a card heading" do
    expect(rendered).to have_css(".nhsuk-card__heading", text: "11 uploads")
  end

  it "renders the headers" do
    expect(rendered).to have_css(".nhsuk-table__header", text: "Uploaded on")
    expect(rendered).to have_css(".nhsuk-table__header", text: "Type")
    expect(rendered).to have_css(".nhsuk-table__header", text: "Status")
    expect(rendered).to have_css(".nhsuk-table__header", text: "Records")
  end

  it "renders the rows" do
    expect(rendered).to have_css(
      ".nhsuk-table__body .nhsuk-table__row",
      count: 11
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "1 January 2020 at 12:00am"
    )
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: CohortImport.first.csv_filename
    )
    expect(rendered).to have_css(".nhsuk-table__cell", text: "Child record")
    expect(rendered).to have_css(
      ".nhsuk-table__cell",
      text: "Vaccination record"
    )
    expect(rendered).to have_css(".nhsuk-table__cell", text: "Class list")
    expect(rendered).to have_css(".nhsuk-table__cell", text: "Completed")
    expect(rendered).to have_css(".nhsuk-table__cell", text: "1")
    expect(rendered).to have_content("Test School")
  end

  context "when uploaded_files is true" do
    let(:uploaded_files) { true }

    it "does not show the Records column header" do
      expect(rendered).not_to have_css(".nhsuk-table__header", text: "Records")
    end

    it "does not show record counts" do
      expect(rendered).not_to have_css(
        ".nhsuk-table__cell",
        text: /Records\s+\d+/m
      )
    end
  end
end
