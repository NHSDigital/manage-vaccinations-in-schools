# frozen_string_literal: true

describe "Parental consent" do
  scenario "Child attends a different school" do
    given_an_hpv_programme_is_underway
    when_i_go_to_the_consent_form
    when_i_fill_in_my_childs_name_and_birthday

    when_i_do_not_confirm_they_attend_the_pilot_school
    then_i_see_a_page_asking_for_the_childs_school

    when_i_click_continue
    then_i_see_an_error

    when_i_choose_a_school
    and_i_fill_in_the_remaining_details
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_confirmation_page
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv

    @team = create(:team, :with_one_nurse, programmes: [@programme])

    @original_location = create(:school, team: @team, name: "Original School")
    @actual_location = create(:school, team: @team, name: "Actual School")

    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location: @original_location
      )

    @child = create(:patient, session: @session)
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def when_i_fill_in_my_childs_name_and_birthday
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
  end

  def when_i_do_not_confirm_they_attend_the_pilot_school
    choose "No, they go to a different school"
    click_on "Continue"
  end

  def then_i_see_a_page_asking_for_the_childs_school
    expect(page).to have_heading("What school does your child go to?")
  end

  def when_i_click_continue
    click_on "Continue"
  end

  def then_i_see_an_error
    expect(page).to have_heading "There is a problem"
  end

  def when_i_choose_a_school
    select "Actual School"
    click_on "Continue"
  end

  def and_i_fill_in_the_remaining_details
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
      "Child’s name#{@child.full_name(context: :parents)}"
    )
  end

  def when_i_submit_the_consent_form
    click_on "Confirm"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Consent confirmed")
    expect(page).to have_content("is due to get the HPV vaccination at school")
    expect(page).not_to have_content(@session.dates.first.to_fs(:long))
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end
end
