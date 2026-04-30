# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "submit when there is no session" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    and_i_am_signed_in

    when_i_go_to_the_consent_form
    when_i_fill_in_my_childs_name_and_birthday

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    then_i_see_the_confirmation_page

    when_i_wait_for_the_background_jobs_to_complete
    then_i_get_a_confirmation_email_and_scheduled_survey_email
    and_i_get_a_confirmation_text
    and_the_consent_form_is_marked_as_confirmation_sent

    when_the_nurse_checks_the_consent_responses
    then_they_see_that_the_child_has_consent
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @team_location =
      TeamLocation.find_by!(team: @team, location: @team.unknown_school)
    @patient =
      create(
        :patient,
        :consent_no_response,
        school: @team.unknown_school,
        location: @team.unknown_school,
        team: @team,
        programmes: [@programme]
      )
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@team_location, @programme)
  end

  def when_i_give_consent
    choose "Yes"
    click_on "Continue"

    expect(page).to have_content("About you")
    fill_in "Full name", with: "Jane #{@patient.family_name}"
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
  end

  def when_i_fill_in_my_childs_name_and_birthday
    click_on "Start now"

    expect(page).to have_content("What is your child’s name?")
    fill_in "First name", with: @patient.given_name
    fill_in "Last name", with: @patient.family_name
    choose "No" # Do they use a different name in school?
    click_on "Continue"

    expect(page).to have_content("What is your child’s date of birth?")
    fill_in "Day", with: @patient.date_of_birth.day
    fill_in "Month", with: @patient.date_of_birth.month
    fill_in "Year", with: @patient.date_of_birth.year
    click_on "Continue"
  end

  def and_i_answer_no_to_all_the_medical_questions
    until page.has_content?("Check and confirm")
      choose "No"
      click_on "Continue"
    end
  end

  def then_i_can_check_my_answers
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content(
      "Child’s name#{@patient.full_name(context: :parents)}"
    )
  end

  def when_i_submit_the_consent_form
    click_on "Confirm"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Consent confirmed")
  end

  def when_i_wait_for_the_background_jobs_to_complete
    ProcessConsentFormSidekiqJob.drain
  end

  def then_i_get_a_confirmation_email_and_scheduled_survey_email
    expect_email_to("jane@example.com", :consent_confirmation_given)
  end

  def and_i_get_a_confirmation_text
    expect_sms_to("07123 456789", :consent_confirmation_given)
  end

  def and_the_consent_form_is_marked_as_confirmation_sent
    expect(ConsentForm.last).to be_confirmation_sent
  end

  def when_the_nurse_checks_the_consent_responses
    visit schools_path
    click_on "Unknown school"
    choose "Due vaccination", match: :first
    click_on "Update results"
  end

  def then_they_see_that_the_child_has_consent
    click_on @patient.full_name
    within(".app-secondary-navigation") { click_on "HPV" }
    expect(page).to have_content("Due vaccination")
  end
end
