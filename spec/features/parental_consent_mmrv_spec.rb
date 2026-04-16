# frozen_string_literal: true

describe "Parental consent" do
  before { given_an_mmr_programme_is_underway }

  scenario "MMRV - any vaccine" do
    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(without_gelatine: false)
    then_i_see_the_first_health_question

    when_i_answer_no_to_all_health_questions
    then_i_see_the_check_and_confirm_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_confirmation_page
  end

  scenario "MMRV - without gelatine" do
    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(without_gelatine: true)
    then_i_see_the_first_health_question

    when_i_answer_no_to_all_health_questions
    then_i_see_the_check_and_confirm_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_confirmation_page
  end

  scenario "MMRV - refusal" do
    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_refuse_consent
    then_i_see_the_follow_up_question

    when_i_answer_no_to_the_follow_up_question_and_continue
    then_i_see_the_check_and_confirm_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_confirmation_page_about_refusal
  end

  def given_an_mmr_programme_is_underway
    @mmr_programme = Programme.mmr
    @mmrv_programme =
      Programme::Variant.new(@mmr_programme, variant_type: "mmrv")
    @team = create(:team, :with_one_nurse, programmes: [@mmr_programme])
    location =
      create(:gias_school, name: "Pilot School", programmes: [@mmr_programme])
    @session =
      create(:session, :scheduled, programmes: [@mmrv_programme], location:)
    @child =
      create(
        :patient,
        session: @session,
        given_name: "River",
        family_name: "Cartwright"
      )
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @mmrv_programme)
  end

  def then_i_see_the_consent_form
    expect(page).to have_content(
      "Give or refuse consent for an MMRV catch-up vaccination"
    )
  end

  def when_i_give_consent(without_gelatine:)
    click_button "Start now"

    # What is your child's name?
    fill_in "First name", with: @child.given_name
    fill_in "Last name", with: @child.family_name
    choose "No"
    click_button "Continue"

    # What is your child's date of birth?
    fill_in "Day", with: @child.date_of_birth.day
    fill_in "Month", with: @child.date_of_birth.month
    fill_in "Year", with: @child.date_of_birth.year
    click_button "Continue"

    # Confirm your child's school
    choose "Yes"
    click_button "Continue"

    # About you
    fill_in "Full name", with: "Jane #{@child.family_name}"
    choose "Mum"
    fill_in "Email address", with: "jane@example.com"
    click_button "Continue"

    # Do you agree?
    choose "Yes, I agree"
    click_button "Continue"

    # Without gelatine
    if without_gelatine
      choose "I want my child to have the vaccine that does not contain gelatine"
    else
      choose "My child can have either type of vaccine"
    end
    click_button "Continue"

    # Home address
    fill_in "Address line 1", with: "1 High Street"
    fill_in "Town or city", with: "London"
    fill_in "Postcode", with: "SW1 1AA"
    click_button "Continue"
  end

  def when_i_refuse_consent
    click_button "Start now"

    # What is your child's name?
    fill_in "First name", with: @child.given_name
    fill_in "Last name", with: @child.family_name
    choose "No"
    click_button "Continue"

    # What is your child's date of birth?
    fill_in "Day", with: @child.date_of_birth.day
    fill_in "Month", with: @child.date_of_birth.month
    fill_in "Year", with: @child.date_of_birth.year
    click_button "Continue"

    # Confirm your child's school
    choose "Yes"
    click_button "Continue"

    # About you
    fill_in "Full name", with: "Jane #{@child.family_name}"
    choose "Mum"
    fill_in "Email address", with: "jane@example.com"
    click_button "Continue"

    # Do you agree?
    choose "No"
    click_button "Continue"

    # Resaon for refusal
    choose "Personal choice"
    click_button "Continue"
  end

  def then_i_see_the_follow_up_question
    expect(page).to have_content(
      "Would you like a member of the team to contact you to discuss alternative options?"
    )
  end

  def when_i_answer_no_to_the_follow_up_question_and_continue
    choose "No"
    click_button "Continue"
  end

  def then_i_see_the_first_health_question
    expect(page).to have_content(
      "Does your child have a bleeding disorder or another medical condition they receive treatment for?"
    )
  end

  def when_i_answer_no_to_all_health_questions
    3.times do
      choose "No"
      click_button "Continue"
    end
  end

  def then_i_see_the_check_and_confirm_page
    expect(page).to have_content("Check and confirm")
  end

  def when_i_submit_the_consent_form
    click_on "Confirm"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("is due to get the MMRV vaccination at school")
  end

  def then_i_see_the_confirmation_page_about_refusal
    expect(page).to have_content(
      "do not want River Cartwright to get the MMRV vaccination at school"
    )
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end
end
