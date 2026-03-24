# frozen_string_literal: true

describe "Parental consent create patient" do
  before { given_the_app_is_setup }

  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Consent form matches an NHS number" do
    stub_pds_search_to_return_a_patient

    when_i_go_to_the_consent_form
    when_i_fill_in_my_childs_name_and_birthday

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    and_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_consent_confirmation_page
    and_i_wait_for_background_jobs_to_complete

    when_the_nurse_checks_the_unmatched_consent_responses
    then_they_see_the_consent_form

    when_the_nurse_clicks_on_the_consent_form
    and_the_nurse_clicks_on_create_record
    then_they_see_the_new_patient_page

    when_the_nurse_submits_the_new_patient
    then_the_patient_and_associated_records_are_created
    and_the_unmatched_consent_responses_page_is_empty

    when_they_check_triage
    then_the_patient_should_be_safe_to_vaccinate
  end

  scenario "Consent form doesn't match an NHS number" do
    stub_pds_search_to_return_no_patients

    when_i_go_to_the_consent_form
    when_i_fill_in_my_childs_name_and_birthday

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    and_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_consent_confirmation_page
    and_i_wait_for_background_jobs_to_complete

    when_the_nurse_checks_the_unmatched_consent_responses
    then_they_see_the_consent_form

    when_the_nurse_clicks_on_the_consent_form
    and_the_nurse_clicks_on_create_record
    then_they_see_the_new_patient_page

    when_the_nurse_submits_the_new_patient
    then_the_patient_and_associated_records_are_created
    and_the_unmatched_consent_responses_page_is_empty

    when_they_check_triage
    then_the_patient_should_be_safe_to_vaccinate
  end

  scenario "Consent form matches an NHS number and patient with same NHS number exists" do
    stub_pds_search_to_return_a_patient

    when_i_go_to_the_consent_form
    when_i_fill_in_my_childs_name_and_birthday

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    and_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_the_consent_confirmation_page
    and_i_wait_for_background_jobs_to_complete

    when_the_nurse_checks_the_unmatched_consent_responses
    then_they_see_the_consent_form

    given_a_patient_with_the_same_nhs_number_is_now_created
    when_the_nurse_clicks_on_the_consent_form
    then_they_are_not_able_to_create_a_new_patient
  end

  def given_the_app_is_setup
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    location = create(:school, name: "Pilot School", team: @team)
    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location:
      )
    @child = build(:patient, year_group: 8) # NB: Build, not create, so we don't persist to DB
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def when_i_give_consent
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

  def and_i_answer_no_to_all_the_medical_questions
    until page.has_content?("Check and confirm")
      choose "No"
      click_on "Continue"
    end
  end

  def and_i_submit_the_consent_form
    click_on "Confirm"
  end

  def then_i_see_the_consent_confirmation_page
    expect(page).to have_content(
      "#{@child.full_name(context: :parents)} is due to get the HPV vaccination at school"
    )
  end

  def and_i_wait_for_background_jobs_to_complete
    perform_enqueued_jobs
  end

  def when_the_nurse_checks_the_unmatched_consent_responses
    sign_in @team.users.first
    visit "/dashboard"

    expect(page).to have_content("Unmatched responses (1)")
    click_on "Unmatched responses"
  end

  def then_they_see_the_consent_form
    expect(page).to have_content(@child.full_name)
    expect(page).to have_link("Match")
    expect(page).to have_link("Archive")
  end

  def given_a_patient_with_the_same_nhs_number_is_now_created
    @existing_patient =
      create(
        :patient,
        nhs_number: "9449306168",
        given_name: @child.given_name,
        family_name: @child.family_name,
        birth_academic_year: @child.birth_academic_year
      )
  end

  def when_the_nurse_clicks_on_the_consent_form
    click_link "Jane #{@child.family_name}", match: :first
  end

  def then_they_are_not_able_to_create_a_new_patient
    expect(page).to have_link("Match")
    expect(page).to have_link("Archive")
    expect(page).not_to have_link("Create new record")
  end

  def and_the_nurse_clicks_on_create_record
    click_link "Create new record"
  end

  def then_they_see_the_new_patient_page
    expect(page).to have_heading("Create a new child record")
    expect(page).to have_content("Full name#{@child.full_name}")
  end

  def when_the_nurse_submits_the_new_patient
    click_button "Create"
  end

  def then_the_patient_and_associated_records_are_created
    expect(Patient.count).to eq(1)
    expect(Patient.last.consents.count).to eq(1)
    expect(Patient.last.parents.count).to eq(1)
    expect(Patient.last.sessions).to include(@session)
  end

  def and_the_unmatched_consent_responses_page_is_empty
    expect(page).to have_content(
      "There are currently no unmatched consent responses."
    )
  end

  def when_they_check_triage
    visit sessions_path
    click_link "Pilot School"
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def then_the_patient_should_be_safe_to_vaccinate
    expect(page).to have_content(@child.full_name)
    click_on @child.full_name
    expect(page).to have_content(
      "#{@child.full_name} is ready for the vaccinator"
    )
    expect(Patient.last.birth_academic_year).to eq(
      @child.date_of_birth.academic_year
    )
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end
end
