# frozen_string_literal: true

describe "Parental consent closed" do
  scenario "Consent form is shown as closed" do
    given_an_hpv_programme_is_underway_with_a_backfilled_session
    when_i_go_to_the_consent_form
    then_i_see_that_consent_is_closed
  end

  scenario "Before parent submits the consent" do
    given_an_hpv_programme_is_starting_soon
    when_i_go_through_the_consent_journey
    then_i_see_the_confirmation_page

    when_i_wait_a_long_time_before_submitting
    then_i_see_that_consent_is_closed
  end

  def given_an_hpv_programme_is_underway_with_a_backfilled_session
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @subteam = create(:subteam, team: @team)
    location = create(:gias_school, name: "Pilot School", subteam: @subteam)
    @session =
      create(
        :session,
        :completed,
        team: @team,
        programmes: [@programme],
        location:,
        date: Date.yesterday
      )
  end

  def given_an_hpv_programme_is_starting_soon
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @subteam = create(:subteam, team: @team)
    location = create(:gias_school, name: "Pilot School", subteam: @subteam)
    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location:,
        date: Date.tomorrow
      )
    @child = create(:patient, :consent_no_response, session: @session)
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def when_i_go_through_the_consent_journey
    visit start_parent_interface_consent_forms_path(@session, @programme)

    click_on "Start now"

    expect(page).to have_content("What is your child’s name?")
    fill_in "First name", with: @child.given_name
    fill_in "Last name", with: @child.family_name
    choose "No" # Do they use a different name in school?
    click_on "Continue"

    expect(page).to have_content("What is your child’s date of birth?")
    fill_in "Day", with: @child.date_of_birth.day
    fill_in "Month", with: @child.date_of_birth.month
    fill_in "Year", with: @child.date_of_birth.year
    click_on "Continue"

    choose "Yes, they go to this school"
    click_on "Continue"

    expect(page).to have_content("About you")
    fill_in "Full name", with: "Jane #{@child.family_name}"
    choose "Mum" # Your relationship to the child
    fill_in "Email address", with: "jane@example.com"
    fill_in "Phone number", with: "07123456789"
    check "Tick this box if you’d like to get updates by text message"
    click_on "Continue"

    expect(page).to have_content("Phone contact method")
    choose "I do not have specific needs"
    click_on "Continue"

    expect(page).to have_content("Do you agree")
    choose "Yes, I agree"
    click_on "Continue"

    expect(page).to have_content("Home address")
    fill_in "Address line 1", with: "1 Test Street"
    fill_in "Address line 2 (optional)", with: "2nd Floor"
    fill_in "Town or city", with: "Testville"
    fill_in "Postcode", with: "TE1 1ST"
    click_on "Continue"

    until page.has_content?("Check and confirm")
      choose "No"
      click_on "Continue"
    end
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
  end

  def when_i_wait_a_long_time_before_submitting
    travel_to(1.day.from_now) { click_on "Confirm" }
  end

  def then_i_see_that_consent_is_closed
    expect(page).to have_content("The deadline for responding has passed")
    expect(page).to have_content(
      "Contact #{@subteam.email} to book a clinic appointment."
    )
  end
end
