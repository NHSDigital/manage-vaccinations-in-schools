# frozen_string_literal: true

describe "Triage" do
  around { |example| travel_to(Date.new(2025, 7, 1)) { example.run } }

  scenario "delay vaccination" do
    given_a_programme_with_a_running_session
    and_i_am_signed_in
    when_i_go_to_the_patients_tab

    when_i_click_on_a_patient
    and_i_choose_to_delay_vaccination
    and_i_enter_a_date_beyond_the_current_academic_year
    and_i_save_triage
    then_i_see_an_error_that_date_cannot_be_beyond_academic_year

    when_i_enter_valid_date
    and_i_save_triage
    then_i_see_an_alert_saying_the_record_was_saved

    when_i_filter_by_delay_vaccination
    then_i_see_the_patient

    when_i_view_the_child_record
    then_they_should_have_the_status_banner_delay_vaccination
    and_the_outcome_should_include_the_date
  end

  def given_a_programme_with_a_running_session
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)
    @school = create(:school, team: @team)
    session =
      create(
        :session,
        team: @team,
        programmes:,
        location: @school,
        date: Time.zone.today
      )
    @patient =
      create(:patient, :consent_given_triage_needed, :in_attendance, session:)
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_go_to_the_patients_tab
    visit "/dashboard"
    click_link "Sessions", match: :first
    click_link @school.name
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def when_i_click_on_a_patient
    click_link @patient.full_name
  end

  def and_i_enter_a_note_and_invite_to_clinic
    fill_in "Triage notes (optional)", with: "Invite to clinic"
    choose "No, invite to clinic"
    and_i_save_triage
  end

  def and_i_choose_to_delay_vaccination
    choose "No, delay vaccination"
  end

  def and_i_enter_a_date_beyond_the_current_academic_year
    fill_in_date(Date.new(2025, 9, 1))
  end

  def when_i_enter_valid_date
    fill_in_date(1.week.from_now)
  end

  def and_i_save_triage
    click_button "Save triage"
  end

  def then_i_see_an_error_that_date_cannot_be_beyond_academic_year
    expect(page).to have_content(
      "The vaccination date cannot go beyond 31 August 2025"
    )
  end

  def then_i_see_an_alert_saying_the_record_was_saved
    expect(page).to have_alert("Success", text: "Triage outcome updated")
  end

  def and_a_vaccination_at_clinic_email_is_sent_to_the_parent
    expect_email_to @patient.consents.first.parent.email,
                    :triage_vaccination_at_clinic
  end

  def when_i_filter_by_delay_vaccination
    within(".nhsuk-breadcrumb") { click_on "Children in session" }
    choose "Unable to vaccinate"
    check "Delay vaccination"
    click_on "Update results"
  end

  def then_i_see_the_patient
    expect(page).to have_content(@patient.full_name)
  end

  def when_i_access_the_vaccinate_later_page
    click_on @school.name, match: :first
    within(".app-secondary-navigation") { click_on "Children" }
    choose "Eligible", match: :first
    click_on "Update results"
  end

  def when_i_view_the_child_record
    click_link @patient.full_name
  end

  def then_they_should_have_the_status_banner_delay_vaccination
    expect(page).to have_content("Delay vaccination")
  end

  def and_the_outcome_should_include_the_date
    expect(page).to have_content("Delay vaccination until 8 July 2025")
  end

  def then_they_should_have_the_status_banner_invited_to_clinic
    expect(page).to have_content("Invite to clinic")
  end

  def and_i_am_not_able_to_record_a_vaccination
    expect(page).not_to have_content("ready for their HPV vaccination?")
  end

  def and_i_am_able_to_update_the_triage
    expect(page).to have_content("Update triage outcome")
  end

  def fill_in_date(date)
    fill_in "Day", with: date.day
    fill_in "Month", with: date.month
    fill_in "Year", with: date.year
  end
end
