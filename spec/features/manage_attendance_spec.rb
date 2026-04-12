# frozen_string_literal: true

describe "Manage attendance" do
  around { |example| travel_to(Time.zone.local(2024, 2, 29)) { example.run } }

  scenario "Recording attendance for a patient" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_there_is_a_vaccination_session_today
    and_the_session_has_patients

    when_i_go_to_the_session
    and_i_click_on_the_children_tab

    when_i_register_a_patient_as_attending
    then_i_see_the_attending_flash

    when_i_register_a_patient_as_absent
    then_i_see_the_absent_flash

    when_i_go_to_the_session_patients
    and_i_go_to_a_patient
    then_the_patient_is_not_registered_yet
    and_i_am_not_able_to_vaccinate

    when_i_choose_the_patient_is_absent
    then_the_patient_is_absent
    and_i_see_the_absent_flash

    when_i_choose_the_patient_has_not_been_registered_yet
    then_the_patient_is_not_registered_yet
    and_i_see_the_not_registered_flash

    when_i_choose_the_patient_is_attending
    then_the_patient_is_attending
    and_i_see_the_attending_flash
    and_i_can_vaccinate

    when_i_go_to_the_activity_log
    then_i_see_the_attendance_event
  end

  scenario "Recording vaccinations where patient does not need registration" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_there_is_a_vaccination_session_today_that_requires_no_registration
    and_the_session_has_patients

    when_i_go_to_the_session
    and_i_click_on_the_children_tab
    then_i_do_not_see_the_registration_buttons

    when_i_go_to_the_session_patients
    and_i_go_to_a_patient
    then_i_should_not_see_link_to_update_attendance
  end

  scenario "Turning off attendance" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_there_is_a_vaccination_session_today
    and_the_session_has_patients

    when_i_go_to_the_session
    and_i_click_on_the_children_tab
    then_i_see_the_registration_buttons

    when_i_go_to_the_session
    and_i_edit_the_session
    and_i_turn_off_register_attendance

    when_i_go_to_the_session
    and_i_click_on_the_children_tab
    then_i_do_not_see_the_registration_buttons
  end

  scenario "Viewing a patient from yesterday with attendance turned off" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_there_is_a_vaccination_session_yesterday_that_requires_no_registration
    and_the_session_has_patients

    when_i_go_to_the_session
    and_i_click_on_the_record_tab
    then_i_cant_see_the_patients

    when_i_go_to_the_session
    and_i_click_on_the_children_tab
    and_i_go_to_a_patient
    then_i_cant_record_a_vaccination
  end

  def given_my_team_is_running_an_hpv_vaccination_programme
    @programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes: @programmes)
  end

  def and_there_is_a_vaccination_session_today
    @session =
      create(
        :session,
        :today,
        programmes: @programmes,
        team: @team,
        location: create(:gias_school, team: @team)
      )
  end

  def and_there_is_a_vaccination_session_today_that_requires_no_registration
    @session =
      create(
        :session,
        :today,
        :requires_no_registration,
        programmes: @programmes,
        team: @team,
        location: create(:gias_school, team: @team)
      )
  end

  def and_there_is_a_vaccination_session_yesterday_that_requires_no_registration
    @session =
      create(
        :session,
        :yesterday,
        :requires_no_registration,
        programmes: @programmes,
        team: @team,
        location: create(:gias_school, team: @team)
      )
  end

  def and_the_session_has_patients
    create_list(
      :patient,
      3,
      :consent_given_triage_not_needed,
      programmes: @programmes,
      session: @session
    )
  end

  def when_i_go_to_the_session
    sign_in @team.users.first
    visit dashboard_path
    click_link "Sessions", match: :first
    click_link @session.location.name
  end

  def and_i_click_on_the_children_tab
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def and_i_click_on_the_record_tab
    click_link "Record vaccinations"
  end

  def then_i_cant_see_the_patients
    expect(page).to have_content(
      "You can record vaccinations when a session is in progress."
    )
  end

  def then_i_should_not_see_link_to_update_attendance
    expect(page).not_to have_content("Update attendance")
  end

  def then_i_see_the_patient
    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def then_i_see_the_registration_buttons
    expect(page).to have_button("Attending")
    expect(page).to have_button("Absent")
  end

  def then_i_do_not_see_the_registration_buttons
    expect(page).not_to have_button("Attending")
    expect(page).not_to have_button("Absent")
  end

  def when_i_register_a_patient_as_attending
    click_button "Attending", match: :first
  end

  def when_i_register_a_patient_as_absent
    click_button "Absent", match: :first
  end

  def when_i_go_to_the_session_patients
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def and_i_go_to_a_patient
    click_link Patient.where.missing(:attendance_records).first.full_name
  end

  def then_the_patient_is_not_registered_yet
    expect(page).to have_content("registered yet")
  end

  def and_i_am_not_able_to_vaccinate
    expect(page).not_to have_content("ready for their HPV vaccination?")
  end

  def when_i_choose_the_patient_has_not_been_registered_yet
    click_link "Update attendance"
    choose "They have not been registered yet", match: :first
    click_button "Save changes"
  end

  def and_i_see_the_not_registered_flash
    expect(page).to have_content("is not registered yet")
  end

  def when_i_choose_the_patient_is_absent
    choose "No, they are absent from today's session"
    click_button "Update attendance"
  end

  def then_the_patient_is_absent
    expect(page).to have_content("is absent from today’s session")
  end

  def and_i_see_the_absent_flash
    expect(page).to have_content("is absent from today")
  end
  alias_method :then_i_see_the_absent_flash, :and_i_see_the_absent_flash

  def when_i_choose_the_patient_is_attending
    choose "Yes, they are attending"
    click_button "Update attendance"
  end

  def then_the_patient_is_attending
    expect(page).to have_content("is attending today’s session")
  end

  def and_i_see_the_attending_flash
    expect(page).to have_content("is attending today")
  end
  alias_method :then_i_see_the_attending_flash, :and_i_see_the_attending_flash

  def and_i_can_vaccinate
    expect(page).to have_content("ready for their HPV vaccination?")
  end

  def when_i_go_to_the_activity_log
    click_link "Session activity and notes"
  end

  def then_i_see_the_attendance_event
    expect(page).to have_content("Attended session")
  end

  def and_i_edit_the_session
    click_on "Edit session"
  end

  def and_i_turn_off_register_attendance
    click_on "Change register attendance"
    choose "No"
    click_on "Continue"
    click_on "Save changes"
  end

  def then_i_cant_record_a_vaccination
    expect(page).not_to have_content("Record vaccination")
  end
end
