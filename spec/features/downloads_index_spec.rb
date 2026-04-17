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

  describe "type filter" do
    let(:programme) { Programme.hpv }

    before do
      exportable =
        create(
          :vaccination_records_export,
          programme_type: programme.type,
          academic_year: 2024,
          file_format: "mavis"
        )
      create(:export, exportable:, team:, user:)

      visit downloads_path
    end

    it "shows only vaccination records when that filter is selected" do
      choose "Vaccination records"
      click_on "Update results"

      within(".app-grid-column-results") do
        expect(page).to have_content("HPV vaccination records")
      end
    end
  end
end
