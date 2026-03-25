# frozen_string_literal: true

describe "Vaccination programmes table" do
  around { |example| travel_to(Date.new(2025, 8, 31)) { example.run } }

  before { given_my_team_exists }

  scenario "patient has non-seasonal vaccine" do
    given_patients_exist_in_year_eleven
    and_the_patient_is_vaccinated_for_hpv

    when_i_click_on_children
    and_i_filter_for_the_child
    and_i_click_on_a_child

    then_the_table_has_a_row_showing_hpv_vaccinated
    and_the_table_shows_other_eligible_vaccinations
  end

  scenario "patient has a seasonal vaccine" do
    given_patients_exist_in_year_eleven
    and_the_patient_had_two_flu_doses_last_year

    when_i_click_on_children
    and_i_filter_for_the_child
    and_i_click_on_a_child

    then_the_table_has_two_rows_showing_flu_vaccinated
  end

  scenario "patient has an outcome other than vaccinated" do
    given_patients_exist_in_year_eleven
    and_the_patient_has_an_outcome_other_than_vaccinated

    when_i_click_on_children
    and_i_filter_for_the_child
    and_i_click_on_a_child

    then_the_table_displays_the_outcome
  end

  def given_my_team_exists
    @programmes = [
      @flu_programme = Programme.flu,
      @hpv_programme = Programme.hpv,
      @menacwy_programme = Programme.menacwy,
      @td_ipv_programme = Programme.td_ipv
    ]

    @team = create(:team, :with_one_nurse, programmes: @programmes)
  end

  def given_patients_exist_in_year_eleven
    school = create(:school, team: @team)

    @session =
      create(
        :session,
        location: school,
        team: @team,
        programmes: @programmes,
        date: Date.tomorrow
      )

    @patient =
      create(
        :patient,
        session: @session,
        year_group: 10,
        given_name: "John",
        family_name: "Smith",
        parents: [create(:parent)],
        school:
      )

    PatientStatusUpdater.call(patient: @patient)
  end

  def when_i_click_on_children
    sign_in @team.users.first

    visit "/dashboard"
    click_on "Children", match: :first
  end

  def and_i_filter_for_the_child
    fill_in "Search", with: "John Smith"
    click_button "Update results"
  end

  def and_i_click_on_a_child
    click_on "SMITH, John"
  end

  def then_the_table_has_a_row_showing_hpv_vaccinated
    expect(page).to have_selector(
      "table.nhsuk-table tbody tr",
      text: "HPV"
    ) do |row|
      expect(row).to have_selector("td.nhsuk-table__cell", text: "Vaccinated")
    end
  end

  def and_the_table_shows_other_eligible_vaccinations
    expect(page).to have_selector(
      "table.nhsuk-table tbody tr",
      text: "Flu (winter 2025)"
    ) do |row|
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Needs consent"
      )
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Request scheduled"
      )
    end

    expect(page).to have_selector(
      "table.nhsuk-table tbody tr",
      text: "MenACWY"
    ) do |row|
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Needs consent"
      )
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Request scheduled"
      )
    end
  end

  def then_the_table_has_two_rows_showing_flu_vaccinated
    expect(page).to have_selector(
      "table.nhsuk-table tbody tr",
      text: "Flu (winter 2024)"
    ) do |row|
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Vaccinated on 1 March 2025"
      )
    end
  end

  def then_the_table_displays_the_outcome
    expect(page).to have_selector(
      "table.nhsuk-table tbody tr",
      text: "HPV"
    ) do |row|
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Unable to vaccinate"
      )
      expect(row).to have_selector(
        "td.nhsuk-table__cell",
        text: "Contraindications"
      )
    end
  end

  def and_the_patient_is_vaccinated_for_hpv
    create(
      :vaccination_record,
      patient: @patient,
      programme: @hpv_programme,
      session: @session,
      performed_at: 6.months.ago
    )
    PatientStatusUpdater.call(patient: @patient)
  end

  def and_the_patient_has_a_second_dose_of_hpv
    create(
      :vaccination_record,
      dose_sequence: 2,
      patient: @patient,
      programme: @hpv_programme,
      session: @session
    )
    PatientStatusUpdater.call(patient: @patient)
  end

  def and_the_patient_had_two_flu_doses_last_year
    create(
      :vaccination_record,
      patient: @patient,
      programme: @flu_programme,
      session: @session,
      performed_at: Time.zone.local(2024, 9, 1)
    )
    create(
      :vaccination_record,
      dose_sequence: 2,
      patient: @patient,
      programme: @flu_programme,
      session: @session,
      performed_at: Time.zone.local(2025, 3, 1)
    )
    PatientStatusUpdater.call(patient: @patient)
  end

  def and_the_patient_has_an_outcome_other_than_vaccinated
    create(
      :triage,
      :do_not_vaccinate,
      patient: @patient,
      programme: @hpv_programme,
      academic_year: AcademicYear.pending
    )
    PatientStatusUpdater.call(patient: @patient)
  end
end
