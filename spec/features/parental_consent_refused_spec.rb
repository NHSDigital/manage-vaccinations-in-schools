# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Refused" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    when_i_go_to_the_consent_form
    then_i_see_the_start_page

    when_i_fill_in_my_details
    then_i_see_the_consent_page

    when_i_refuse_consent
    then_i_see_the_follow_up_question
    when_i_request_follow_up
    then_i_can_check_my_answers

    when_i_change_my_refusal_reason
    then_the_consent_doesnt_have_follow_up_requested_stored

    when_i_confirm_my_answers
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_confirmation_page

    when_i_wait_for_the_background_jobs_to_complete
    and_i_receive_an_email_confirming_that_my_child_wont_be_vaccinated
    and_i_receive_a_text_confirming_that_my_child_wont_be_vaccinated

    when_the_nurse_checks_the_consent_responses
    then_they_see_that_the_child_has_consent_refused
  end

  scenario "Refused with follow-up discussion requested" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    when_i_go_to_the_consent_form
    then_i_see_the_start_page

    when_i_fill_in_my_details
    then_i_see_the_consent_page

    when_i_refuse_consent_and_request_follow_up
    then_i_can_check_my_answers_with_follow_up

    when_i_confirm_my_answers
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_follow_up_confirmation_page

    when_i_wait_for_the_background_jobs_to_complete
    and_i_receive_an_email_confirming_follow_up_was_requested
    and_i_receive_a_text_confirming_follow_up_was_requested
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    location = create(:gias_school, name: "Pilot School", team: @team)
    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location:
      )
    @child = create(:patient, session: @session)
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def then_i_see_the_start_page
    expect(page).to have_content(
      "Give or refuse consent for the HPV vaccination"
    )
  end

  def when_i_refuse_consent
    expect(page).to have_content("Do you agree")
    choose "No"
    click_on "Continue"

    expect(page).to have_content(
      "Please tell us why you do not agree to your child having the HPV vaccination"
    )
    choose "Medical reasons"
    click_on "Continue"

    expect(page).to have_content(
      "What medical reasons prevent your child from being vaccinated?"
    )
    fill_in "Give details", with: "They have a weakened immune system"
    click_on "Continue"
  end

  def then_i_see_the_follow_up_question
    expect(page).to have_content(
      "Would you like a member of the team to contact you to discuss alternative options?"
    )
  end

  def when_i_request_follow_up
    choose "Yes, I would like someone to contact me"
    click_on "Continue"
  end

  def when_i_change_my_refusal_reason
    click_on "Change reason for refusal"
    choose "Vaccine already received"
    click_on "Continue"

    fill_in "Give details",
            with: "They will receive the vaccine at another location"
    click_on "Continue"
  end

  def then_the_consent_doesnt_have_follow_up_requested_stored
    expect(ConsentForm.last.follow_up_requested).to be_nil
  end

  def when_i_refuse_consent_and_request_follow_up
    expect(page).to have_content("Do you agree")
    choose "No"
    click_on "Continue"

    expect(page).to have_content(
      "Please tell us why you do not agree to your child having the HPV vaccination"
    )
    choose "Medical reasons"
    click_on "Continue"

    expect(page).to have_content(
      "What medical reasons prevent your child from being vaccinated?"
    )
    fill_in "Give details", with: "They have a weakened immune system"
    click_on "Continue"

    expect(page).to have_content(
      "Would you like a member of the team to contact you to discuss alternative options?"
    )
    choose "Yes, I would like someone to contact me"
    click_on "Continue"
  end

  def when_i_fill_in_my_details
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

    expect(page).to have_content("Confirm your child’s school")
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
  end

  def then_i_see_the_consent_page
    expect(page).to have_content("Do you agree")
  end

  def then_i_can_check_my_answers
    expect(page).to have_content("Check and confirm")
  end

  def when_i_confirm_my_answers
    click_on "Confirm"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content(
      "You’ve told us that you do not want #{@child.full_name(context: :parents)} to get the HPV vaccination at school"
    )
  end

  def when_i_wait_for_the_background_jobs_to_complete
    ProcessConsentFormSidekiqJob.drain
  end

  def and_i_receive_an_email_confirming_that_my_child_wont_be_vaccinated
    expect(email_deliveries).to include(
      matching_notify_email(
        to: "jane@example.com",
        template: :consent_confirmation_refused
      ).with_content_including(
        "You have told us you do not want",
        "If you change your mind, please contact us"
      )
    )
  end

  def and_i_receive_a_text_confirming_that_my_child_wont_be_vaccinated
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: "07123 456789",
        template: :consent_confirmation_refused
      ).with_content_including(
        "You have told us you do not want",
        "give feedback"
      )
    )
  end

  def when_the_nurse_checks_the_consent_responses
    sign_in @team.users.first
    visit sessions_path
    click_on "Pilot School"
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def then_they_see_that_the_child_has_consent_refused
    expect(page).to have_content("Consent refused")
    choose "Has a refusal"
    click_on "Update results"
    expect(page).to have_content(@child.full_name)
  end

  def then_i_can_check_my_answers_with_follow_up
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Discuss options")
    expect(page).to have_content("Yes")
  end

  def then_i_see_the_follow_up_confirmation_page
    expect(page).to have_content("You've asked for a follow-up")
    expect(page).to have_content(
      "A member of the team will contact you soon to discuss your options."
    )
  end

  def and_i_receive_an_email_confirming_follow_up_was_requested
    expect(email_deliveries).to include(
      matching_notify_email(
        to: "jane@example.com",
        template: :consent_confirmation_refused
      ).with_content_including(
        "You have told us you do not want",
        "You’ve also asked for someone to contact you about alternative options"
      )
    )
  end

  def and_i_receive_a_text_confirming_follow_up_was_requested
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: "07123 456789",
        template: :consent_confirmation_refused
      ).with_content_including(
        "You have told us you do not want",
        "You've also asked for someone to contact you about alternative options"
      )
    )
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end
end
