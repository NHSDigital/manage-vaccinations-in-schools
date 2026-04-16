# frozen_string_literal: true

RSpec.feature "Parental consent change answers" do
  before { given_a_flu_programme_is_underway }

  scenario "Health questions contain Yes answers" do
    when_i_go_to_a_prefilled_consent_form
    then_i_see_the_consent_form_confirmation_page

    when_i_change_my_parental_relationship_to_other
    then_i_see_the_parental_responsibility_error

    when_i_refuse_parental_responsibility
    then_i_see_the_cannot_consent_responsibility_page

    when_i_accept_parental_responsibility
    then_i_see_the_consent_form_confirmation_page

    when_i_change_my_parental_relationship_to_dad
    then_i_see_the_consent_form_confirmation_page

    when_i_change_the_patients_name
    then_i_see_the_updated_name

    when_i_click_on_the_change_link_of_the_first_answer
    then_i_see_the_health_question

    when_i_change_my_answer_to_yes_for_the_asthma_question
    then_i_see_the_first_follow_up_question

    when_i_answer_yes_to_the_follow_up_question_and_continue
    then_i_see_the_second_follow_up_question

    when_i_answer_yes_to_the_second_follow_up_question_and_continue
    then_i_see_the_consent_form_confirmation_page
    and_i_see_the_answer_i_changed_is_yes

    when_i_click_back
    then_i_see_the_last_health_question
    and_i_answer_no_to_the_last_health_question

    when_i_click_the_confirm_button
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_needs_triage_confirmation_page
  end

  scenario "Consent refused" do
    when_i_go_to_a_prefilled_consent_form
    then_i_see_the_consent_form_confirmation_page

    when_i_change_my_consent_to_refused
    and_say_the_reason_is_that_the_vaccine_contains_gelatine
    then_i_see_the_follow_up_question

    when_i_answer_no_to_the_follow_up_question_and_continue
    then_i_see_the_consent_form_confirmation_page

    when_i_change_my_consent_to_accepted
    then_i_see_the_injection_alternative_page

    when_i_input_the_injection_alternative
    then_i_see_the_address_page

    when_i_input_my_address
    then_i_see_the_first_health_question
  end

  scenario "Add phone number before submitting" do
    when_i_go_to_a_prefilled_consent_form(with_phone: false)
    then_i_see_the_consent_form_confirmation_page

    when_i_change_my_phone_number
    and_i_choose_my_phone_contact_method
    then_i_see_the_consent_form_confirmation_page

    when_i_click_the_confirm_button
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_given_confirmation_page
  end

  def given_a_flu_programme_is_underway
    programmes = [Programme.flu]
    @team = create(:team, :with_one_nurse, programmes:)
    location = create(:gias_school, name: "Pilot School", team: @team)
    @session = create(:session, :scheduled, team: @team, programmes:, location:)
    @child = create(:patient, session: @session)
  end

  def when_i_go_to_a_prefilled_consent_form(with_phone: true)
    visit "/random-consent-form?session_id=#{@session.id}&parent_phone=#{with_phone}"
  end

  def then_i_see_the_consent_form_confirmation_page
    expect(page).to have_content("Check and confirm")
  end

  def when_i_change_my_parental_relationship_to_other
    click_link "Change your relationship"

    expect(page).to have_content("About you")
    choose "Other"
    click_button "Continue"
  end

  def then_i_see_the_parental_responsibility_error
    expect(page).to have_content(
      "You need parental responsibility to give consent"
    )
  end

  def when_i_refuse_parental_responsibility
    choose "No"
    click_button "Continue"
  end

  def then_i_see_the_cannot_consent_responsibility_page
    expect(page).to have_content(
      "You cannot give or refuse consent through this service"
    )
  end

  def when_i_accept_parental_responsibility
    click_link "Back"
    choose "Other"
    fill_in "Relationship to the child", with: "Granddad"
    choose "Yes" # Parental responsibility
    click_button "Continue"

    expect(page).to have_content("Phone contact method")
    choose "I do not have specific needs"
    click_on "Continue"

    # BUG: The page should be the consent confirm page, but because we
    # encountered a validation error, the skip_to_confirm flag gets lost and we
    # end up on the next page in the wizard.
    click_button "Continue"

    # BUG: You shouldn't need to select again if injection is accepted as an
    # alternative.
    choose "Yes"
    click_button "Continue"

    # BUG: You shouldn't need to answer the health questions again.
    9.times { click_button "Continue" }

    # BUG: You shouldn't need to choose this again. It happens because the
    # injection alternative value is lost when changing answers.
    choose "No"
    click_button "Continue"
  end

  def when_i_change_my_parental_relationship_to_dad
    click_link "Change your relationship"
    choose "Dad"
    click_button "Continue"
  end

  def when_i_change_the_patients_name
    click_link "Change child’s name"
    fill_in "First name", with: "Joe"
    fill_in "Last name", with: "Test"
    click_button "Continue"
  end

  def then_i_see_the_updated_name
    expect(page).to have_content("Joe Test")
  end

  def when_i_click_on_the_change_link_of_the_first_answer
    click_link "Change your answer to health question 1"
  end

  def then_i_see_the_health_question
    expect(page).to have_content("Has your child been diagnosed with asthma?")
  end

  def when_i_change_my_answer_to_yes_for_the_asthma_question
    choose "Yes"
    click_button "Continue"
  end

  def then_i_see_the_first_follow_up_question
    expect(page).to have_content(
      "Have they taken oral steroids in the last 2 weeks?"
    )
  end

  def when_i_answer_yes_to_the_follow_up_question_and_continue
    choose "Yes"
    fill_in "Give details", with: "Follow up details"
    click_button "Continue"
  end

  def when_i_answer_yes_to_the_second_follow_up_question_and_continue
    choose "Yes"
    fill_in "Give details", with: "Even more follow up details"
    click_button "Continue"
  end

  def then_i_see_the_second_follow_up_question
    expect(page).to have_content(
      "Have they been admitted to intensive care for their asthma?"
    )
  end

  def and_i_see_the_answer_i_changed_is_yes
    expect(page).to have_content("Yes – Follow up details")
    expect(page).to have_content("Yes – Even more follow up details")
  end

  def when_i_click_back
    click_link "Back"
  end

  def then_i_see_the_last_health_question
    expect(page).to have_content(
      "Does your child have a bleeding disorder or another medical condition they receive treatment for?"
    )
  end

  def and_i_answer_no_to_the_last_health_question
    choose "No"
    click_button "Continue"
  end

  def when_i_change_my_consent_to_refused
    click_link "Change decision"
    choose "No"
    click_button "Continue"
  end

  def when_i_change_my_consent_to_accepted
    click_link "Change decision"
    choose "Yes, I agree to them having the nasal spray vaccine"
    click_button "Continue"
  end

  def and_say_the_reason_is_that_the_vaccine_contains_gelatine
    choose "I’m concerned the nasal vaccine contains gelatine"
    click_button "Continue"
  end

  def then_i_see_the_follow_up_question
    expect(page).to have_content(
      "Would you like a member of the team to contact you to discuss alternative options?"
    )
    expect(page).to have_content(
      "For example, it may be possible to use a vaccine that does not contain gelatine."
    )
  end

  def when_i_answer_no_to_the_follow_up_question_and_continue
    choose "No"
    click_button "Continue"
  end

  def when_i_click_the_confirm_button
    click_button "Confirm"
  end

  def then_i_see_the_needs_triage_confirmation_page
    expect(page).to have_content("Consent confirmed")
    expect(page).to have_content(
      "As you answered ‘yes’ to some of the health questions, we need to " \
        "check the nasal spray flu vaccination is suitable for Joe Test."
    )
  end

  def then_i_see_the_refused_confirmation_page
    expect(page).to have_content(
      "Your child will not get the flu vaccination at school"
    )
  end

  def then_i_see_the_given_confirmation_page
    expect(page).to have_content(
      "is due to get the nasal spray flu vaccination at school"
    )
  end

  def then_i_see_the_injection_alternative_page
    expect(page).to have_content(
      "If your child cannot have the nasal spray, do you agree to them having the injected vaccine instead?"
    )
  end

  def when_i_input_the_injection_alternative
    choose "Yes"
    click_button "Continue"
  end

  def then_i_see_the_address_page
    expect(page).to have_content("Home address")
  end

  def when_i_input_my_address
    fill_in "Address line 1", with: "123 Test Street"
    fill_in "Town or city", with: "Testington"
    fill_in "Postcode", with: "TE1 1ST"
    click_button "Continue"
  end

  def then_i_see_the_first_health_question
    expect(page).to have_content("Has your child been diagnosed with asthma?")
  end

  def when_i_change_my_phone_number
    click_on "Change your phone"
    choose "Mum"
    fill_in "Phone number", with: "07700 900001"
    click_on "Continue"
  end

  def and_i_choose_my_phone_contact_method
    choose "I can only receive text messages"
    click_on "Continue"
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end
end
