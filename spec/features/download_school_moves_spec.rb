# frozen_string_literal: true

describe "Download school moves" do
  scenario "no dates given" do
    given_i_am_signed_in
    and_school_moves_exist
    and_i_go_to_school_moves
    when_i_click_on_download_records
    then_i_see_the_export_form

    perform_enqueued_jobs { click_on "Download school move data" }

    then_i_am_on_the_downloads_page
    and_the_export_is_ready

    when_i_click_the_download_link
    then_i_get_a_csv_file_with_expected_row_count(2)
  end

  scenario "dates supplied" do
    given_i_am_signed_in
    and_school_moves_exist
    and_i_go_to_school_moves
    when_i_click_on_download_records
    when_i_enter_some_dates

    perform_enqueued_jobs { click_on "Download school move data" }

    then_i_am_on_the_downloads_page
    and_the_export_is_ready

    when_i_click_the_download_link
    then_i_get_a_csv_file_with_expected_row_count(1)
  end

  def given_i_am_signed_in
    team = create(:team, :with_one_nurse)
    @session = create(:session, team:)
    @patients =
      create_list(
        :patient,
        2,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )

    sign_in team.users.first
  end

  def and_school_moves_exist
    create(
      :school_move_log_entry,
      patient: @patients.first,
      school: @session.location
    )
    create(
      :school_move_log_entry,
      patient: @patients.second,
      school: @session.location,
      created_at: Time.zone.local(2024, 6, 15) # Middle of the date range
    )
  end

  def and_i_go_to_school_moves
    visit school_moves_path
  end

  def when_i_click_on_download_records
    click_on "Download records"
  end

  def then_i_see_the_export_form
    expect(page).to have_content("Download school moves")
    expect(page).to have_button("Download school move data")
  end

  def when_i_enter_some_dates
    within all(".nhsuk-fieldset")[0] do
      fill_in "Day", with: "01"
      fill_in "Month", with: "01"
      fill_in "Year", with: "2024"
    end

    within all(".nhsuk-fieldset")[1] do
      fill_in "Day", with: "31"
      fill_in "Month", with: "12"
      fill_in "Year", with: "2024"
    end
  end

  def then_i_am_on_the_downloads_page
    expect(page).to have_current_path(downloads_path)
  end

  def and_the_export_is_ready
    visit downloads_path
    expect(page).to have_content("School moves")
    expect(page).to have_content("Ready")
  end

  def when_i_click_the_download_link
    click_on "School moves"
  end

  def then_i_get_a_csv_file_with_expected_row_count(expected_count)
    expect(page).to have_content(
      Reports::SchoolMovesExporter::HEADERS.join(",")
    )
    csv_content = CSV.parse(page.body, headers: true)
    expect(csv_content.size).to eq(expected_count)
  end
end
