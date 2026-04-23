# frozen_string_literal: true

describe "Clinic sessions" do
  around { |example| travel_to(Time.zone.local(2024, 2, 18)) { example.run } }

  scenario "adding a new session, sending reminders and closing consent" do
    given_my_team_is_running_an_hpv_vaccination_programme
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    then_i_see_no_sessions

    when_i_click_on_the_unknown_school
    and_i_click_on_the_patient
    and_i_record_a_new_vaccination
    then_i_see_the_community_clinic_session

    when_i_go_to_todays_sessions_as_a_nurse
    then_i_see_the_community_clinic

    when_i_go_to_todays_sessions_as_a_nurse
    and_i_go_to_completed_sessions
    then_i_see_no_sessions

    when_the_parent_visits_the_consent_form
    then_they_can_give_consent

    when_the_deadline_has_passed
    then_they_can_no_longer_give_consent
    and_i_am_signed_in

    when_i_go_to_todays_sessions_as_a_nurse
    and_i_go_to_completed_sessions
    then_i_see_the_community_clinic
  end

  def given_my_team_is_running_an_hpv_vaccination_programme
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    @parent = create(:parent)

    @patient =
      create(
        :patient,
        :consent_no_response,
        year_group: 8,
        school: @team.unknown_school,
        parents: [@parent],
        programmes: [@programme]
      )
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_go_to_todays_sessions_as_a_nurse
    visit "/dashboard"

    click_link "Sessions", match: :first

    choose "Community clinic"
    choose "In progress"

    click_on "Update results"
  end

  def when_i_go_to_unscheduled_sessions
    choose "Unscheduled"
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

  def when_i_click_on_the_unknown_school
    click_on "Schools"
    click_on "Unknown school"
  end

  def and_i_click_on_the_patient
    click_on @patient.full_name
  end

  def and_i_record_a_new_vaccination
    within(".app-secondary-navigation") { click_on "HPV" }
    click_on "Record a vaccination in clinic"
  end

  def then_i_see_the_community_clinic_session
    click_on "Back"
    expect(page).to have_content("HPV community clinic")
    expect(page).to have_content("18 February 2024")
  end

  def then_i_see_the_community_clinic
    expect(page).to have_content("Community clinic")
    expect(page).not_to have_content("Import class list")
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

  def then_they_can_no_longer_give_consent
    visit start_parent_interface_consent_forms_path(Session.last, @programme)
    expect(page).to have_content("The deadline for responding has passed")
  end
end
