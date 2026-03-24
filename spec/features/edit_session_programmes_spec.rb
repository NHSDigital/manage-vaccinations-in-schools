# frozen_string_literal: true

describe "Edit session programmes" do
  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  scenario "add new programme to existing session" do
    given_a_school_exists
    and_the_school_has_unvaccinated_catch_up_patients
    and_an_hpv_session_already_exists

    when_i_visit_the_session_page
    and_i_click_on_edit_session
    and_i_add_the_mmr_programme
    then_i_see_the_warning_panel_about_unvaccinated_patients_for_hpv_and_mmr

    when_i_click_continue
    then_i_should_see_the_hpv_and_mmr_programme
  end

  scenario "choosing HPV only programme with a high number of unvaccinated catch up patients" do
    given_a_school_exists
    and_the_school_has_unvaccinated_catch_up_patients

    when_i_visit_the_school_page
    and_i_create_a_new_session
    and_i_choose_the_hpv_programme
    and_i_choose_the_year_groups
    and_i_choose_the_date
    then_i_see_the_warning_panel_about_unvaccinated_patients_for_hpv

    when_i_click_keep_session_dates
    then_i_should_see_the_hpv_programme
  end

  scenario "choosing MMR only programme with a high number of unvaccinated catch up patients" do
    given_a_school_exists
    and_the_school_has_unvaccinated_catch_up_patients

    when_i_visit_the_school_page
    and_i_create_a_new_session
    and_i_choose_the_mmr_programme
    and_i_choose_the_year_groups
    and_i_choose_the_date
    then_i_see_the_warning_panel_about_unvaccinated_patients_for_mmr

    when_i_click_keep_session_dates
    and_i_select_standard_consent_requests
    then_i_should_see_the_mmr_programme
  end

  scenario "choosing HPV and MMR programmes with a high number of unvaccinated catch up patients" do
    given_a_school_exists
    and_the_school_has_unvaccinated_catch_up_patients

    when_i_visit_the_school_page
    and_i_create_a_new_session
    and_i_choose_the_hpv_and_mmr_programmes
    and_i_choose_the_year_groups
    and_i_choose_the_date
    then_i_see_the_warning_panel_about_unvaccinated_patients_for_hpv_and_mmr

    when_i_click_keep_session_dates
    and_i_select_standard_consent_requests
    then_i_should_see_the_hpv_and_mmr_programme
  end

  def given_a_school_exists
    @programmes = [Programme.hpv, Programme.mmr]

    @team = create(:team, :with_one_nurse, programmes: @programmes)

    @location = create(:gias_school, team: @team, programmes: @programmes)
  end

  def and_an_hpv_session_already_exists
    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        location: @location,
        programmes: [Programme.hpv]
      )
  end

  def and_the_school_has_unvaccinated_catch_up_patients
    create_list(
      :patient,
      2,
      :consent_no_response,
      location: @location,
      year_group: 9,
      programmes: @programmes
    )
  end

  def when_i_visit_the_session_page
    sign_in @team.users.first
    visit session_path(@session)
  end

  def when_i_visit_the_school_page
    sign_in @team.users.first
    visit school_sessions_path(@location)
  end

  def and_i_click_on_edit_session
    click_on "Edit session"
  end

  def and_i_add_the_mmr_programme
    click_on "Change programmes"
    check "MMR"
    click_on "Continue"
  end

  def and_i_create_a_new_session
    click_on "Add a new session"
  end

  def and_i_choose_the_hpv_programme
    check "HPV"
    click_on "Continue"
  end

  def and_i_choose_the_mmr_programme
    check "MMR"
    click_on "Continue"
  end

  def and_i_choose_the_hpv_and_mmr_programmes
    check "HPV"
    check "MMR"
    click_on "Continue"
  end

  def and_i_choose_the_year_groups
    check "Year 8"
    check "Year 9"
    check "Year 10"
    check "Year 11"
    click_on "Continue"
  end

  def and_i_choose_the_date
    fill_in "Year", with: "2024"
    fill_in "Month", with: "2"
    fill_in "Day", with: "8"
    click_on "Continue"
  end

  def then_i_see_the_warning_panel_about_unvaccinated_patients_for_hpv
    expect(page).to have_content(
      "Have you imported historical vaccination records for HPV?"
    )
    expect(page).to have_content(
      "0% of children in Years 9 to 11 in this session have vaccination " \
        "records."
    )
    expect(page).to have_content(
      "Scheduling this session now will send consent requests to 2 parents " \
        "of children in Years 9 to 11 on 18 January 2024. Many of them may " \
        "be parents of already vaccinated children."
    )
  end

  def then_i_see_the_warning_panel_about_unvaccinated_patients_for_mmr
    expect(page).to have_content(
      "Have you imported historical vaccination records for MMR(V)?"
    )
    expect(page).to have_content(
      "0% of children in Years 8 to 11 in this session have vaccination " \
        "records."
    )
    expect(page).to have_content(
      "Scheduling this session now will send consent requests to 2 parents " \
        "of children in Years 8 to 11 on 18 January 2024. Many of them may " \
        "be parents of already vaccinated children."
    )
  end

  def then_i_see_the_warning_panel_about_unvaccinated_patients_for_hpv_and_mmr
    expect(page).to have_content(
      "Have you imported historical vaccination records for HPV and MMR(V)?"
    )
    expect(page).to have_content(
      "0% of children in Years 8 to 11 in this session have vaccination " \
        "records."
    )
    expect(page).to have_content(
      "Scheduling this session now will send consent requests to 2 parents " \
        "of children in Years 8 to 11 on 18 January 2024. Many of them may " \
        "be parents of already vaccinated children."
    )
  end

  def when_i_click_continue
    click_on "Continue"
  end

  def when_i_click_keep_session_dates
    click_on "Keep session dates"
  end

  def and_i_select_standard_consent_requests
    choose "Standard request"
    click_on "Continue"
  end

  def then_i_should_see_the_hpv_programme
    expect(page).to have_content("ProgrammesHPV")
  end

  def then_i_should_see_the_mmr_programme
    expect(page).to have_content("ProgrammesMMR")
  end

  def then_i_should_see_the_hpv_and_mmr_programme
    expect(page).to have_content("ProgrammesHPV MMR")
  end
end
