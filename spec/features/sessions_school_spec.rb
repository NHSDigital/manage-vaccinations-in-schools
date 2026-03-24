# frozen_string_literal: true

describe "School sessions" do
  around { |example| travel_to(Time.zone.local(2024, 2, 18)) { example.run } }

  scenario "adding a new session, closing consent, closing the session, then sending clinic invitations" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    then_i_see_no_sessions

    when_i_click_on_add_a_new_session
    and_i_choose_the_school
    and_i_choose_the_programmes
    and_i_choose_the_year_groups
    then_i_see_the_dates_page

    when_i_add_an_invalid_date
    then_i_see_a_validation_error

    when_i_choose_the_dates
    then_i_see_the_confirmation_page

    when_i_press_back_enough_time_to_see_the_programmes
    then_i_click_continue_back_to_the_confirmation_page

    when_i_click_on_change_programmes
    then_i_see_the_change_programmes_page
    and_i_change_the_programmes
    then_i_see_the_new_programme

    when_i_click_on_change_consent_requests
    then_i_see_the_change_consent_requests_page
    and_i_change_consent_requests_date

    when_i_click_on_change_consent_reminders
    then_i_see_the_change_consent_reminders_page
    and_i_change_consent_reminders_weeks

    when_i_save_the_session
    then_i_should_see_the_session_details

    when_i_go_to_todays_sessions_as_a_nurse
    then_i_see_no_sessions

    when_i_go_to_scheduled_sessions
    then_i_see_the_school
    and_i_see_a_child_in_the_cohort

    when_i_go_to_completed_sessions
    then_i_see_no_sessions

    when_the_parent_visits_the_consent_form
    then_they_can_give_consent

    when_the_deadline_has_passed
    and_patients_have_been_seen
    then_they_can_no_longer_give_consent
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    and_i_go_to_completed_sessions
    then_i_see_the_school

    when_i_click_on_the_school
    and_i_click_on_edit_dates
    then_i_see_the_dates_page_but_cannot_change

    and_i_click_on_send_invitations
    then_i_see_the_send_invitations_page

    when_i_click_on_send_invitations
    then_i_see_the_invitation_confirmation
    then_i_see_the_school
    and_the_parent_receives_an_invitation
  end

  scenario "sending clinic invitations to unvaccinated children uses RT5-specific template for RT5 teams" do
    given_my_team_is_running_an_hpv_vaccination_programme_for_ods_code("RT5")
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    and_i_go_to_completed_sessions
    when_i_click_on_the_school
    and_i_click_on_send_invitations
    then_i_see_the_send_invitations_page
    when_i_click_on_send_invitations
    then_i_see_the_invitation_confirmation
    then_the_parent_receives_an_rt5_clinic_invitation
  end

  scenario "sending clinic invitations to unvaccinated children uses RYG-specific template for RYG teams" do
    given_my_team_is_running_an_hpv_vaccination_programme_for_ods_code("RYG")
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    and_i_go_to_completed_sessions
    when_i_click_on_the_school
    and_i_click_on_send_invitations
    then_i_see_the_send_invitations_page
    when_i_click_on_send_invitations
    then_i_see_the_invitation_confirmation
    then_the_parent_receives_a_ryg_clinic_invitation
  end

  def given_my_team_is_running_an_hpv_vaccination_programme
    @programme = Programme.hpv
    @other_programme = Programme.flu

    programmes = [@programme, @other_programme]

    @team = create(:team, :with_one_nurse, programmes:)
    @location = create(:school, :secondary, team: @team, programmes:)

    @parent = create(:parent)

    @patient =
      create(
        :patient,
        :consent_no_response,
        year_group: 8,
        location: @location,
        parents: [@parent],
        programmes:
      )

    clinic_session =
      create(
        :session,
        date: 1.month.from_now.to_date,
        team: @team,
        location: @team.generic_clinic,
        programmes: [@programme, @other_programme]
      )

    patient_already_in_clinic_without_invitation =
      create(:patient, year_group: 8, location: @location)
    create(
      :patient_location,
      patient: patient_already_in_clinic_without_invitation,
      session: clinic_session
    )

    patient_already_in_clinic_with_invitation =
      create(:patient, year_group: 8, location: @location)
    create(
      :patient_location,
      patient: patient_already_in_clinic_with_invitation,
      session: clinic_session
    )
    create(
      :clinic_notification,
      :initial_invitation,
      session: clinic_session,
      patient: patient_already_in_clinic_with_invitation
    )
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_go_to_todays_sessions_as_a_nurse
    visit "/dashboard"

    click_link "Sessions", match: :first

    choose "In progress"
    click_on "Update results"
  end

  def when_i_go_to_unscheduled_sessions
    choose "Unscheduled"
    click_on "Update results"
  end

  def when_i_search_for_the_school
    fill_in "Search", with: @location.name
    click_on "Update results"
  end

  def when_i_go_to_scheduled_sessions
    choose "Scheduled"
    click_on "Update results"
  end

  def when_i_go_to_completed_sessions
    choose "Completed"
    click_on "Update results"
  end

  alias_method :and_i_go_to_completed_sessions, :when_i_go_to_completed_sessions

  def then_i_see_no_sessions
    expect(page).to have_content("No sessions matching search criteria found")
  end

  def when_i_click_on_the_school
    click_link @location.name
  end

  def then_i_see_the_school_session
    expect(page).to have_content(@location.name)
    expect(page).to have_content(@location.urn)
    expect(page).to have_content("No dates scheduled")
  end

  def and_i_see_a_child_in_the_cohort
    expect(page).to have_content("3 children")
  end

  def and_i_click_on_edit_dates
    click_on "Edit session"
    click_on "Change session dates"
  end

  def when_i_click_on_add_a_new_session
    click_on "Add a new session"
  end

  def and_i_choose_the_school
    expect(page).to have_content("What type of session is this?")

    choose "School"
    click_on "Continue"

    expect(page).to have_content("Where is this school session taking place?")

    select @location.name
    click_on "Continue"
  end

  def and_i_choose_the_programmes
    expect(page).to have_content(
      "Which programmes will you run in this session?"
    )

    check "HPV"
    click_on "Continue"
  end

  def and_i_choose_the_year_groups
    expect(page).to have_content(
      "Which year groups do you want to invite to this session?"
    )

    expect(page).not_to have_content("Reception")
    # "Year 1" exists in "Year 11"
    expect(page).not_to have_content("Year 2")
    expect(page).not_to have_content("Year 3")
    expect(page).not_to have_content("Year 4")
    expect(page).not_to have_content("Year 5")
    expect(page).not_to have_content("Year 6")
    expect(page).not_to have_content("Year 7")
    expect(page).not_to have_content("Year 12")
    expect(page).not_to have_content("Year 13")

    check "Year 8"
    check "Year 9"
    check "Year 10"
    check "Year 11"
    click_on "Continue"
  end

  def then_i_see_the_dates_page_but_cannot_change
    expect(page).to have_content(
      "Children have attended this session. It cannot be changed."
    )

    click_on "Continue"
    click_on "Save changes"
  end

  def then_i_see_the_dates_page
    expect(page).to have_content("When will this session be held?")
  end

  def when_i_add_an_invalid_date
    fill_in "Day", with: "99"
    fill_in "Month", with: "99"
    fill_in "Year", with: "99"
    click_on "Continue"
  end

  def then_i_see_a_validation_error
    expect(page).to have_content("Enter a date")
  end

  def when_i_choose_the_dates
    fill_in "Day", with: "10"
    fill_in "Month", with: "03"
    fill_in "Year", with: "2024"
    click_on "Add another date"

    within all(".app-add-another__list-item")[1] do
      fill_in "Day", with: "11"
      fill_in "Month", with: "03"
      fill_in "Year", with: "2024"
    end
    click_on "Add another date"

    within all(".app-add-another__list-item")[2] do
      fill_in "Day", with: "12"
      fill_in "Month", with: "03"
      fill_in "Year", with: "2024"
    end

    click_on "Add another date"

    within all(".app-add-another__list-item")[3] do
      click_on "Delete"
    end

    within all(".app-add-another__list-item")[2] do
      click_on "Delete"
    end

    click_on "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Year groupsYears 8 to 11")
    expect(page).to have_link("Change year groups")
    expect(page).to have_content("Register attendanceYes")
  end

  def when_i_press_back_enough_time_to_see_the_programmes
    3.times { click_on "Back" }
    expect(page).to have_content(
      "Which programmes will you run in this session?"
    )
  end

  def then_i_click_continue_back_to_the_confirmation_page
    click_on "Continue"
    expect(page).to have_content("Check and confirm")
  end

  def when_i_click_on_change_programmes
    click_on "Change programmes"
  end

  def then_i_see_the_change_programmes_page
    expect(page).to have_content(
      "Which programmes will you run in this session?"
    )
  end

  def and_i_change_the_programmes
    check "Flu"
    click_on "Continue"
  end

  def then_i_see_the_new_programme
    expect(page).to have_content("ProgrammesFlu HPV")
  end

  def when_i_click_on_change_consent_requests
    click_on "Change consent requests"
  end

  def then_i_see_the_change_consent_requests_page
    expect(page).to have_content(
      "When should parents get a request to give consent?"
    )
  end

  def and_i_change_consent_requests_date
    fill_in "Day", with: "1"
    fill_in "Month", with: "3"
    fill_in "Year", with: "2024"
    click_on "Continue"
  end

  def when_i_click_on_change_consent_reminders
    click_on "Change consent reminders"
  end

  def then_i_see_the_change_consent_reminders_page
    expect(page).to have_content(
      "When should parents get a reminder to give consent?"
    )
  end

  def and_i_change_consent_reminders_weeks
    fill_in "When should parents get a reminder to give consent?", with: "1"
    click_on "Continue"
  end

  def when_i_save_the_session
    click_on "Continue"
  end

  def then_i_should_see_the_session_details
    expect(page).to have_content(@location.name.to_s)
    expect(page).to have_content("10 – 11 March 2024")
  end

  def when_the_parent_visits_the_consent_form
    visit start_parent_interface_consent_forms_path(Session.last, @programme)
  end

  def then_they_can_give_consent
    expect(page).to have_content("Give or refuse consent for vaccinations")
  end

  def when_the_deadline_has_passed
    travel_to(Time.zone.local(2024, 3, 12))
  end

  def and_patients_have_been_seen
    create(
      :attendance_record,
      :present,
      patient: @patient,
      session: Session.last
    )
  end

  def then_they_can_no_longer_give_consent
    visit start_parent_interface_consent_forms_path(Session.last, @programme)
    expect(page).to have_content("The deadline for responding has passed")
  end

  def then_i_see_the_school
    expect(page).to have_content(@location.name)
  end

  def when_i_click_on_send_invitations
    click_on "Send clinic invitations"
  end

  def then_i_see_the_send_invitations_page
    expect(page).to have_content("Invite parents to book a clinic appointment")
    expect(page).to have_content(
      "2 children were not vaccinated at this school and have not already been invited to a clinic."
    )
  end

  alias_method :and_i_click_on_send_invitations,
               :when_i_click_on_send_invitations

  def then_i_see_the_invitation_confirmation
    expect(page).to have_content("2 children invited to the clinic")
  end

  def and_the_parent_receives_an_invitation
    perform_enqueued_jobs

    expect_email_to @parent.email, :clinic_initial_invitation
    expect_sms_to @parent.phone, :clinic_initial_invitation, :any
  end

  def given_my_team_is_running_an_hpv_vaccination_programme_for_ods_code(
    ods_code
  )
    @programme = Programme.hpv
    @other_programme = Programme.flu

    programmes = [@programme, @other_programme]

    @team = create(:team, :with_one_nurse, programmes:, ods_code:)
    @location = create(:school, :secondary, team: @team, programmes:)

    @parent = create(:parent)

    @patient =
      create(
        :patient,
        :consent_no_response,
        year_group: 8,
        location: @location,
        parents: [@parent],
        programmes:
      )

    school_session =
      create(
        :session,
        :completed,
        team: @team,
        location: @location,
        programmes: [@programme, @other_programme]
      )

    create(
      :attendance_record,
      :present,
      patient: @patient,
      session: school_session
    )

    clinic_session =
      create(
        :session,
        date: 1.month.from_now.to_date,
        team: @team,
        location: @team.generic_clinic,
        programmes: [@programme, @other_programme]
      )

    patient_already_in_clinic_without_invitation =
      create(:patient, year_group: 8, location: @location)
    create(
      :patient_location,
      patient: patient_already_in_clinic_without_invitation,
      session: clinic_session
    )

    patient_already_in_clinic_with_invitation =
      create(:patient, year_group: 8, location: @location)
    create(
      :patient_location,
      patient: patient_already_in_clinic_with_invitation,
      session: clinic_session
    )
    create(
      :clinic_notification,
      :initial_invitation,
      session: clinic_session,
      patient: patient_already_in_clinic_with_invitation
    )
  end

  def then_the_parent_receives_an_rt5_clinic_invitation
    perform_enqueued_jobs
    expect_email_to @parent.email, :clinic_initial_invitation_rt5
    expect_sms_to @parent.phone, :clinic_initial_invitation_rt5, :any
  end

  def then_the_parent_receives_a_ryg_clinic_invitation
    perform_enqueued_jobs
    expect_email_to @parent.email, :clinic_initial_invitation_ryg
    expect_sms_to @parent.phone, :clinic_initial_invitation_ryg, :any
  end
end
