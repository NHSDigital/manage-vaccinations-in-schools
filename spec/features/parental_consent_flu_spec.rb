# frozen_string_literal: true

describe "Parental consent" do
  before { given_ethnicity_capture_is_enabled }

  scenario "Flu" do
    given_a_flu_programme_is_underway
    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(nasal_spray: true)
    then_i_see_the_first_health_question

    when_i_answer_no_to_all_health_questions(nasal_spray: true)
    then_i_see_the_confirmation_page

    when_i_change_my_answer_to_the_first_health_question
    then_i_see_the_follow_up_question

    when_i_answer_the_follow_up_questions
    then_i_see_the_confirmation_page

    when_i_click_on_confirm
    then_i_see_the_ethnicity_question_page

    when_i_choose_yes_to_answering_ethnicity_questions
    and_i_choose_an_ethnic_group
    and_i_choose_an_ethnic_background
    then_i_see_the_consent_confirmation_page
    and_the_patient_is_updated_with_the_ethnicity_information
  end

  scenario "Flu - already has a PSD won't need triage and consented to nasal" do
    stub_pds_search_to_return_no_patients

    given_a_flu_programme_is_underway
    and_the_child_has_a_psd

    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(nasal_spray: true)
    when_i_answer_no_to_all_health_questions(nasal_spray: true)
    then_i_see_the_confirmation_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_the_psd_is_not_invalidated
  end

  scenario "Flu - already has a PSD won't need triage but refused nasal" do
    stub_pds_search_to_return_no_patients

    given_a_flu_programme_is_underway
    and_the_child_has_a_psd

    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(nasal_spray: false)
    when_i_answer_no_to_all_health_questions(nasal_spray: false)
    then_i_see_the_confirmation_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_the_psd_is_invalidated
  end

  scenario "Flu - already has a PSD will need triage" do
    stub_pds_search_to_return_no_patients

    given_a_flu_programme_is_underway
    and_the_child_has_a_psd

    when_i_go_to_the_consent_form
    then_i_see_the_consent_form

    when_i_give_consent(nasal_spray: true)
    when_i_answer_yes_to_all_health_questions
    then_i_see_the_confirmation_page

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_the_psd_is_invalidated
  end

  def given_ethnicity_capture_is_enabled
    Flipper.enable(:ethnicity_capture)
  end

  def given_a_flu_programme_is_underway
    @programme = Programme.flu
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    location =
      create(:gias_school, name: "Pilot School", programmes: [@programme])
    @session = create(:session, :scheduled, programmes: [@programme], location:)
    @child = create(:patient, session: @session)
    stub_pds_search_to_return_a_patient(@child.nhs_number)
  end

  def and_the_child_has_a_psd
    @patient_specific_direction =
      create(
        :patient_specific_direction,
        patient: @child,
        programme: @programme
      )
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def then_i_see_the_consent_form
    expect(page).to have_content(
      "Give or refuse consent for your child’s flu vaccination"
    )
  end

  def when_i_give_consent(nasal_spray:)
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

    if nasal_spray
      # Do you agree?
      choose "Yes, I agree to them having the nasal spray vaccine"
      click_button "Continue"

      # Injection alternative
      choose "Yes"
    else
      choose "Yes, I agree to the alternative flu injection"
    end
    click_button "Continue"

    # Home address
    fill_in "Address line 1", with: "1 High Street"
    fill_in "Town or city", with: "London"
    fill_in "Postcode", with: "SW1 1AA"
    click_button "Continue"
  end

  def then_i_see_the_first_health_question
    expect(page).to have_content("Has your child been diagnosed with asthma?")
  end

  def when_i_answer_no_to_all_health_questions(nasal_spray:)
    (nasal_spray ? 9 : 4).times do
      choose "No"
      click_button "Continue"
    end
  end

  def when_i_answer_yes_to_all_health_questions
    11.times do
      choose "Yes"

      begin
        fill_in "Give details", with: "Details"
      rescue Capybara::ElementNotFound
        # Some questions don't have a give details text box.
      end

      click_button "Continue"
    end
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
  end

  def when_i_change_my_answer_to_the_first_health_question
    click_link "Change your answer to health question 1"

    choose "Yes"
    click_button "Continue"
  end

  def then_i_see_the_follow_up_question
    expect(page).to have_content(
      "Have they taken oral steroids in the last 2 weeks?"
    )
  end

  def when_i_answer_the_follow_up_questions
    2.times do
      choose "No"
      click_button "Continue"
    end
  end

  def when_i_submit_the_consent_form
    click_on "Confirm"
  end

  def then_the_psd_is_invalidated
    expect(@patient_specific_direction.reload).to be_invalidated
  end

  def then_the_psd_is_not_invalidated
    expect(@patient_specific_direction.reload).not_to be_invalidated
  end

  def when_i_click_on_confirm
    click_button "Confirm"
  end

  def then_i_see_the_ethnicity_question_page
    expect(page).to have_content(
      "Do you want to answer the ethnicity questions?"
    )
  end

  def when_i_choose_yes_to_answering_ethnicity_questions
    choose "Yes, answer the ethnicity questions (takes less than a minute)"
    click_button "Continue"
  end

  def and_i_choose_an_ethnic_group
    choose "Mixed or multiple ethnic groups"
    click_button "Continue"
  end

  def and_i_choose_an_ethnic_background
    perform_enqueued_jobs do
      choose "White and Black Caribbean"
      click_button "Continue"
    end
  end

  def and_the_ethnicity_information_is_shown
    expect(page).to have_content(
      "Mixed or multiple ethnic groups (White and Black Caribbean)"
    )
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    perform_enqueued_jobs do
      choose "No, skip the ethnicity questions"
      click_on "Continue"
    end
  end

  def then_i_see_the_consent_confirmation_page
    expect(page).to have_content("Consent confirmed")
  end

  def and_the_patient_is_updated_with_the_ethnicity_information
    expect(@child.reload).to have_attributes(
      ethnic_group: "mixed_or_multiple_ethnic_groups",
      ethnic_background: "mixed_white_and_black_caribbean"
    )
  end
end
