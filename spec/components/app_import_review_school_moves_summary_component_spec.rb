# frozen_string_literal: true

describe AppImportReviewSchoolMovesSummaryComponent do
  subject(:rendered) { render_inline(component) }

  let(:component) { described_class.new(changesets:) }
  let(:academic_year) { AcademicYear.current }
  let(:team) { create(:team) }
  let(:import) { create(:cohort_import, team:) }
  let(:changesets) { [] }

  describe "table structure" do
    let(:school) { create(:school, team:, name: "Test School") }
    let(:patient) { create(:patient, school:) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 1)]
    end

    it "renders a table" do
      expect(rendered).to have_css("table.nhsuk-table-responsive")
    end

    it "renders table headers" do
      expect(rendered).to have_css("th", text: "CSV file row")
      expect(rendered).to have_css("th", text: "Name and NHS number")
      expect(rendered).to have_css("th", text: "School move")
    end
  end

  describe "with school move to different school (same team)" do
    let(:current_school) { create(:school, team:, name: "Current School") }
    let(:destination_school) { create(:school, team:, name: "New School") }
    let(:patient) do
      create(
        :patient,
        given_name: "John",
        family_name: "Dover",
        nhs_number: "9435797881",
        school: current_school
      )
    end
    let(:changesets) do
      [
        create(
          :patient_changeset,
          :with_school_move,
          import:,
          patient:,
          row_number: 5,
          school: destination_school
        )
      ]
    end

    it "displays CSV file row number" do
      expect(rendered).to have_css("td", text: "7")
    end

    it "displays patient name" do
      expect(rendered).to have_css("td", text: /DOVER, John/i)
    end

    it "displays NHS number" do
      expect(rendered).to have_css(
        "td .nhsuk-u-secondary-text-colour",
        text: "943 579 7881"
      )
    end

    it "displays current school name" do
      expect(rendered).to have_css("td", text: "Current School")
    end

    it "displays destination school name" do
      expect(rendered).to have_css("td", text: "New School")
    end

    it "displays 'to' between schools" do
      expect(rendered).to have_css(
        "td .nhsuk-u-secondary-text-colour",
        text: "to"
      )
    end

    it "does not show inter-team move message" do
      expect(rendered).not_to have_css(".app-status", text: /moving in from/)
    end
  end

  describe "with inter-team school move" do
    let(:other_team) { create(:team, name: "Other Team") }
    let(:current_school) do
      create(:school, name: "Current School").tap do |s|
        s.attach_to_team!(other_team, academic_year:)
      end
    end
    let(:destination_school) do
      create(:school, name: "Destination School").tap do |s|
        s.attach_to_team!(team, academic_year:)
      end
    end
    let(:patient) { create(:patient, school: current_school) }
    let(:changesets) do
      [
        create(
          :patient_changeset,
          :with_school_move,
          import:,
          patient:,
          row_number: 3,
          school: destination_school
        )
      ]
    end

    it "displays inter-team move status message" do
      expect(rendered).to have_css(
        ".app-status",
        text: /This child is moving in from Other Team's area/i
      )
    end

    it "displays both school names" do
      expect(rendered).to have_css("td", text: "Current School")
      expect(rendered).to have_css("td", text: "Destination School")
    end
  end

  describe "with move to home educated" do
    let(:current_school) { create(:school, team:, name: "Current School") }
    let(:patient) { create(:patient, school: current_school) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 2)]
    end

    before do
      changesets.first.data["review"]["school_move"] = {
        "school_id" => nil,
        "home_educated" => true
      }
      changesets.first.save!
    end

    it "displays 'Home educated' as destination" do
      expect(rendered).to have_css("td", text: "Home educated")
    end

    it "displays current school" do
      expect(rendered).to have_css("td", text: "Current School")
    end
  end

  describe "with unknown destination school" do
    let(:current_school) { create(:school, team:, name: "Current School") }
    let(:patient) { create(:patient, school: current_school) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 1)]
    end

    before do
      changesets.first.data["review"]["school_move"] = {
        "school_id" => nil,
        "home_educated" => false
      }
      changesets.first.save!
    end

    it "displays 'Unknown school' as destination" do
      expect(rendered).to have_css("td", text: "Unknown school")
    end
  end

  describe "with changeset not from file (no row_number)" do
    let(:school) { create(:school, team:) }
    let(:patient) { create(:patient, school:) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: nil)]
    end

    before do
      changesets.first.data["review"]["school_move"] = {
        "school_id" => school.id,
        "home_educated" => false
      }
      changesets.first.save!
    end

    it "displays empty string for row number" do
      first_cell = rendered.css("tbody tr td").first
      row_number = first_cell.text.sub("CSV file row", "").strip
      expect(row_number).to be_empty
    end

    it "still displays patient and school information" do
      expect(rendered).to have_css("td", text: patient.full_name)
    end
  end

  describe "with patient without NHS number" do
    let(:school) { create(:school, team:) }
    let(:patient) { create(:patient, school:, nhs_number: nil) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 1)]
    end

    before do
      changesets.first.data["review"]["school_move"] = {
        "school_id" => school.id,
        "home_educated" => false
      }
      changesets.first.save!
    end

    it "displays 'Not provided' for NHS number" do
      expect(rendered).to have_css("td", text: "Not provided")
    end
  end

  describe "with patient without school" do
    let(:destination_school) { create(:school, team:, name: "New School") }
    let(:patient) { create(:patient, school: nil) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 1)]
    end

    before do
      changesets.first.data["review"]["school_move"] = {
        "school_id" => destination_school.id,
        "home_educated" => false
      }
      changesets.first.save!
    end

    it "displays 'Unknown school' for current school" do
      expect(rendered).to have_css("td", text: "Unknown school")
    end

    it "displays destination school" do
      expect(rendered).to have_css("td", text: "New School")
    end
  end

  describe "with multiple changesets" do
    let(:school_a) { create(:school, team:, name: "School A") }
    let(:school_b) { create(:school, team:, name: "School B") }
    let(:patient_a) do
      create(
        :patient,
        school: school_a,
        given_name: "Alice",
        family_name: "Smith"
      )
    end
    let(:patient_b) do
      create(
        :patient,
        school: school_a,
        given_name: "Bob",
        family_name: "Jones"
      )
    end
    let(:changesets) do
      [
        create(:patient_changeset, import:, patient: patient_a, row_number: 1),
        create(:patient_changeset, import:, patient: patient_b, row_number: 2)
      ]
    end

    before do
      changesets[0].data["review"]["school_move"] = {
        "school_id" => school_b.id,
        "home_educated" => false
      }
      changesets[1].data["review"]["school_move"] = {
        "school_id" => school_b.id,
        "home_educated" => false
      }
      changesets.each(&:save!)
    end

    it "renders all changesets" do
      rows = rendered.css("tbody .nhsuk-table__row")
      expect(rows.size).to eq(2)
    end

    it "displays correct names for each patient" do
      expect(rendered).to have_css("td", text: /SMITH, Alice/i)
      expect(rendered).to have_css("td", text: /JONES, Bob/i)
    end

    it "displays school moves for both patients" do
      rows = rendered.css("tbody .nhsuk-table__row")

      rows.each do |row|
        expect(row.text).to include("School A")
        expect(row.text).to include("to")
        expect(row.text).to include("School B")
      end
    end
  end

  describe "with empty changesets" do
    let(:changesets) { [] }

    it "renders empty table body" do
      expect(rendered).to have_css("tbody")
      expect(rendered).not_to have_css("tbody tr")
    end
  end

  describe "school with multiple teams" do
    let(:team2) { create(:team, name: "Team 2") }
    let(:current_school) do
      create(:school, name: "Multi-Team School").tap do |s|
        s.attach_to_team!(team, academic_year:)
      end
    end
    let(:destination_school) do
      create(:school, name: "Destination School").tap do |s|
        s.attach_to_team!(team2, academic_year:)
      end
    end
    let(:patient) { create(:patient, school: current_school, academic_year:) }
    let(:changesets) do
      [create(:patient_changeset, import:, patient:, row_number: 1)]
    end

    before do
      current_school.attach_to_team!(team2, academic_year:)
      changesets.first.data["review"]["school_move"] = {
        "school_id" => destination_school.id,
        "home_educated" => false
      }
      changesets.first.save!
    end

    it "does not show inter-team message when schools share a team" do
      expect(rendered).not_to have_css(".app-status", text: /moving in from/)
    end
  end
end
