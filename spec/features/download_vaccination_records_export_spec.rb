# frozen_string_literal: true

describe "Download vaccination reports (single page)" do
  scenario "Download a vaccination report" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists

    when_i_visit_the_single_page_form
    then_i_do_not_see_careplus_as_an_option

    when_i_fill_in_the_form
    then_i_download_a_csv_file
  end

  scenario "Validation errors when required fields are missing" do
    given_an_hpv_programme_is_underway

    when_i_visit_the_single_page_form
    and_i_submit_without_filling_in_the_form
    then_i_see_validation_errors
  end

  scenario "Download a vaccination report in CarePlus format" do
    given_an_hpv_programme_is_underway_and_care_plus_is_enabled
    and_an_administered_vaccination_record_exists

    when_i_visit_the_single_page_form
    and_i_fill_in_the_form_with_careplus_format
    then_i_download_a_careplus_file
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    @session = create(:session, team: @team, programmes: [@programme])

    @patient =
      create(
        :patient,
        :consent_given_triage_safe_to_vaccinate,
        given_name: "John",
        family_name: "Smith",
        programmes: [@programme],
        team: @team
      )

    create(:patient_location, patient: @patient, session: @session)
  end

  def given_an_hpv_programme_is_underway_and_care_plus_is_enabled
    given_an_hpv_programme_is_underway
    @team =
      create(
        :team,
        :with_one_nurse,
        :with_careplus_enabled,
        programmes: [@programme]
      )
  end

  def and_an_administered_vaccination_record_exists
    vaccine = @programme.vaccines.first
    batch = create(:batch, :not_expired, team: @team, vaccine:)

    create(
      :vaccination_record,
      programme: @programme,
      patient: @patient,
      session: @session,
      batch:
    )
  end

  def when_i_visit_the_single_page_form
    sign_in @team.users.first
    visit new_vaccination_records_export_path
  end

  def then_i_do_not_see_careplus_as_an_option
    expect(page).not_to have_content("CarePlus")
  end

  def when_i_fill_in_the_form
    fill_in_the_form(file_format: "CSV")
  end

  def and_i_fill_in_the_form_with_careplus_format
    fill_in_the_form(file_format: "CSV for CarePlus (System C)")
  end

  def fill_in_the_form(file_format:)
    choose "#{AcademicYear.current} to #{AcademicYear.current + 1}"
    choose "HPV"
    choose file_format
    perform_enqueued_jobs { click_on "Download vaccination data" }
  end

  def and_i_submit_without_filling_in_the_form
    click_on "Download vaccination data"
  end

  def then_i_download_a_csv_file
    expect(page).to have_current_path(downloads_path)
    expect(page).to have_content("Ready")
    click_on "HPV vaccination records"
    expect(page.status_code).to eq(200)
    expect(page).to have_content("ORGANISATION_CODE")
  end

  def then_i_see_validation_errors
    expect(page).to have_content("There is a problem")
    expect(page).to have_content("Choose a programme")
    expect(page).to have_content("Choose a file format")
  end

  def then_i_download_a_careplus_file
    expect(page).to have_current_path(downloads_path)
    expect(page).to have_content("Ready")
    click_on "HPV vaccination records"
    expect(page.status_code).to eq(200)
    expect(page).to have_content(
      "NHS Number,Surname,Forename,Date of Birth,Address Line 1"
    )
  end
end
