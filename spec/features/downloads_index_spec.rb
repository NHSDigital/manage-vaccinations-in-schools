# frozen_string_literal: true

describe "Downloads index" do
  let(:team) { create(:team, :with_one_nurse, programmes: [Programme.hpv]) }
  let(:user) { team.users.first }

  before { sign_in user }

  it "shows the page" do
    visit downloads_path
    expect(page).to have_content("Downloads")
  end

  it "shows an empty list when no exports exist" do
    visit downloads_path
    within(".app-grid-column-results") do
      expect(page).not_to have_css(".nhsuk-card")
    end
  end

  describe "location export card" do
    context "when location is a clinic" do
      before do
        exportable = create(:location_export)
        create(:export, exportable:, team:, user:)
        visit downloads_path
      end

      it "does not show a school row" do
        within(".nhsuk-card", text: "Community clinic offline session") do
          expect(page).not_to have_css("dt", text: "School")
        end
      end
    end

    context "when location is a school" do
      let(:school) { create(:gias_school, team:) }

      before do
        exportable = create(:location_export, location: school)
        create(:export, exportable:, team:, user:)
        visit downloads_path
      end

      it "shows the school name" do
        within(".nhsuk-card", text: school.name) do
          expect(page).to have_css("dt", text: "School")
          expect(page).to have_content(school.name)
        end
      end
    end
  end

  describe "offline session export card" do
    let(:programme) { Programme.hpv }
    let(:location) { create(:gias_school, team:, programmes: [programme]) }
    let(:session) do
      create(:session, team:, location:, programmes: [programme])
    end

    before do
      exportable = create(:session_export, session:)
      create(:export, exportable:, team:, user:)
      visit downloads_path
    end

    it "shows the school name" do
      within(".nhsuk-card", text: location.name) do
        expect(page).to have_css("dt", text: "School")
        expect(page).to have_content(location.name)
      end
    end
  end

  describe "vaccination records export card" do
    let(:programme) { Programme.hpv }
    let(:exportable) do
      create(
        :vaccination_records_export,
        programme_type: programme.type,
        academic_year: 2024,
        file_format: "mavis"
      )
    end

    before do
      create(:export, exportable:, team:, user:)
      visit downloads_path
    end

    it "shows programme, academic year and format" do
      expect(page).to have_content("Programme")
      expect(page).to have_content(programme.name)
      expect(page).to have_content("Academic year")
      expect(page).to have_content("2024 to 2025")
      expect(page).to have_content("Format")
      expect(page).to have_content("CSV")
    end

    it "does not show a date range row when no dates set" do
      expect(page).not_to have_content("Date range")
    end

    context "when date_from and date_to are set" do
      let(:exportable) do
        create(
          :vaccination_records_export,
          programme_type: programme.type,
          academic_year: 2024,
          file_format: "mavis",
          date_from: Date.new(2024, 9, 1),
          date_to: Date.new(2025, 7, 31)
        )
      end

      it "shows a date range row" do
        expect(page).to have_content("Date range")
        expect(page).to have_content("1 September 2024")
        expect(page).to have_content("31 July 2025")
      end
    end
  end

  describe "school moves export card" do
    before do
      exportable = create(:school_moves_export)
      create(:export, exportable:, team:, user:)
      visit downloads_path
    end

    it "does not show a date range row when no dates set" do
      expect(page).not_to have_content("Date range")
    end

    context "when date_from and date_to are set" do
      before do
        exportable =
          create(
            :school_moves_export,
            date_from: Date.new(2024, 9, 1),
            date_to: Date.new(2025, 7, 31)
          )
        create(:export, exportable:, team:, user:)
        visit downloads_path
      end

      it "shows a date range row" do
        expect(page).to have_content("Date range")
        expect(page).to have_content("1 September 2024")
        expect(page).to have_content("31 July 2025")
      end
    end
  end

  describe "type filter" do
    let(:programme) { Programme.hpv }
    let(:school) { create(:gias_school, team:, programmes: [programme]) }
    let(:session) do
      create(:session, team:, location: school, programmes: [programme])
    end

    before do
      exportable = create(:location_export, location: school)
      create(:export, exportable:, team:, user:)

      exportable = create(:session_export, session:)
      create(:export, exportable:, team:, user:)

      exportable =
        create(
          :vaccination_records_export,
          programme_type: programme.type,
          academic_year: 2024,
          file_format: "mavis"
        )
      create(:export, exportable:, team:, user:)

      exportable = create(:school_moves_export)
      create(:export, exportable:, team:, user:)

      visit downloads_path
    end

    it "shows only offline session exports when that filter is selected" do
      choose "Offline session"
      click_on "Update results"

      within(".app-grid-column-results") do
        expect(page).to have_content("#{school.name} offline session")
      end
    end

    it "shows only vaccination records when that filter is selected" do
      choose "Vaccination records"
      click_on "Update results"

      within(".app-grid-column-results") do
        expect(page).to have_content("HPV vaccination records")
      end
    end

    it "shows only school moves exports when that filter is selected" do
      choose "School moves"
      click_on "Update results"

      within(".app-grid-column-results") do
        expect(page).to have_content("School moves")
      end
    end
  end
end
