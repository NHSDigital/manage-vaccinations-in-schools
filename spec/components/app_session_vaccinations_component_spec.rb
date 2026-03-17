# frozen_string_literal: true

describe AppSessionVaccinationsComponent do
  subject(:rendered) { render_inline(component) }

  let(:hpv_programme) { Programme.hpv }
  let(:menacwy_programme) { Programme.menacwy }
  let(:flu_programme) { Programme.flu }
  let(:flu_injection_vaccine) { flu_programme.vaccines.injection.first }
  let(:flu_nasal_vaccine) { flu_programme.vaccines.nasal.first }
  let(:session) do
    create(
      :session,
      programmes: [hpv_programme, flu_programme, menacwy_programme],
      date: today
    )
  end
  let(:today) { Date.current }
  let(:component) { described_class.new(session) }

  def expect_tally(session_date, column_name, count)
    table = page.find("table.nhsuk-table-responsive")
    row = table.find("tr", text: session_date)
    headers = table.all("th").map(&:text)
    column_index = headers.index(column_name)

    expect(column_index).not_to be_nil,
    "Column '#{column_name}' not found in headers: #{headers}"

    cells = row.all("th, td")
    cell_value = cells[column_index].text.strip

    expect(cell_value).to eq(count.to_s),
    "Expected #{column_name} for #{session_date} to be #{count} but got #{cell_value}"
  end

  def formatted_date(date) = date.strftime("%e %B %Y")

  context "with session in progress but no vaccinations" do
    it "displays zero tallies for all programmes" do
      today_formatted = formatted_date(today)

      rendered

      expect_tally(today_formatted, "Flu (nasal spray)", 0)
      expect_tally(today_formatted, "Flu (injection)", 0)
      expect_tally("Total", "Flu (nasal spray)", 0)
      expect_tally("Total", "Flu (injection)", 0)
      expect_tally(today_formatted, "HPV", 0)
      expect_tally("Total", "HPV", 0)
    end
  end

  context "with vaccinations across multiple session dates" do
    let(:yesterday) { Date.yesterday }
    let(:yesterday_formatted) { formatted_date(yesterday) }
    let(:today_formatted) { formatted_date(today) }

    let(:session) do
      create(
        :session,
        programmes: [hpv_programme, flu_programme, menacwy_programme],
        dates: [yesterday, Date.current]
      )
    end

    before do
      create_vaccination_record(hpv_programme, yesterday, year_group: 9)
      create_vaccination_record(
        hpv_programme,
        yesterday,
        year_group: 9,
        discarded: true
      )
      create_vaccination_record(
        flu_programme,
        today,
        year_group: 9,
        vaccine: flu_injection_vaccine
      )
      create_vaccination_record(
        flu_programme,
        today,
        year_group: 9,
        vaccine: flu_injection_vaccine
      )
      create_vaccination_record(
        flu_programme,
        today,
        year_group: 9,
        vaccine: flu_nasal_vaccine
      )
    end

    it "displays the correct tallies by date" do
      rendered

      expect_tally(yesterday_formatted, "HPV", 1)
      expect_tally("Total", "HPV", 1)

      expect_tally(today_formatted, "Flu (injection)", 2)
      expect_tally("Total", "Flu (injection)", 2)

      expect_tally(today_formatted, "Flu (nasal spray)", 1)
      expect_tally("Total", "Flu (nasal spray)", 1)
    end
  end

  context "with age-based programme filtering" do
    let(:yesterday) { Date.yesterday }
    let(:yesterday_formatted) { formatted_date(yesterday) }

    let(:session) do
      create(
        :session,
        programmes: [hpv_programme, flu_programme, menacwy_programme],
        dates: [yesterday, Date.current]
      )
    end

    before do
      # HPV: Create vaccinations for Years 7, 8, 9 (only 8, 9 should count)
      create_vaccination_record(hpv_programme, yesterday, year_group: 7)
      create_vaccination_record(hpv_programme, yesterday, year_group: 8)
      create_vaccination_record(hpv_programme, yesterday, year_group: 9)

      # MenACWY: Create vaccinations for Years 8, 9, 10 (only 9, 10 should count)
      create_vaccination_record(menacwy_programme, yesterday, year_group: 8)
      create_vaccination_record(menacwy_programme, yesterday, year_group: 9)
      create_vaccination_record(menacwy_programme, yesterday, year_group: 10)

      # Flu: Create vaccinations for Years 7, 8, 10 (all should count)
      create_vaccination_record(
        flu_programme,
        yesterday,
        year_group: 7,
        vaccine: flu_injection_vaccine
      )
      create_vaccination_record(
        flu_programme,
        yesterday,
        year_group: 8,
        vaccine: flu_nasal_vaccine
      )
      create_vaccination_record(
        flu_programme,
        yesterday,
        year_group: 10,
        vaccine: flu_injection_vaccine
      )
    end

    it "only counts vaccinations for patients eligible for each programme" do
      rendered

      # HPV targets birth years [2012, 2011, 2010, 2009] = Years 8, 9, 10, 11
      expect_tally(yesterday_formatted, "HPV", 2) # Year 8 + Year 9
      expect_tally("Total", "HPV", 2)

      # MenACWY targets birth years [2011, 2010, 2009] = Years 9, 10, 11
      expect_tally(yesterday_formatted, "MenACWY", 2) # Year 9 + Year 10
      expect_tally("Total", "MenACWY", 2)

      # Flu targets all years - all should be counted
      expect_tally(yesterday_formatted, "Flu (injection)", 2) # Year 7 + Year 10
      expect_tally(yesterday_formatted, "Flu (nasal spray)", 1) # Year 8
      expect_tally("Total", "Flu (injection)", 2)
      expect_tally("Total", "Flu (nasal spray)", 1)
    end
  end

  private

  def create_vaccination_record(
    programme,
    performed_at,
    year_group:,
    vaccine: nil,
    discarded: false
  )
    patient = create(:patient, session:, year_group:)
    vaccine ||= programme.vaccines.active.first
    batch = create(:batch, :not_expired, vaccine:)
    delivery_method = vaccine&.nasal? ? "nasal_spray" : "intramuscular"
    discarded_at = discarded ? Time.current : nil

    create(
      :vaccination_record,
      delivery_method:,
      discarded_at:,
      patient:,
      performed_at:,
      programme:,
      session:,
      vaccine:,
      batch:
    )
  end
end
