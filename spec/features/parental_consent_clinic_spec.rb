# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Child attending a clinic goes to a school" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    and_an_upcoming_school_session_exists

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    then_i_see_a_page_asking_if_my_child_is_home_educated

    when_i_choose_no_they_go_to_a_school
    then_i_see_a_page_asking_for_the_childs_school

    when_i_click_continue
    then_i_see_an_error

    when_i_choose_a_school
    then_i_see_the_parent_step

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_a_confirmation_page_in_school

    when_the_nurse_checks_the_school_moves
    then_the_nurse_should_see_one_move
    and_the_nurse_confirms_the_move

    when_the_nurse_checks_the_patient(in_the_school: true)
    then_the_nurse_should_see_the_school
  end

  scenario "Child attending a clinic is home-schooled" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    then_i_see_a_page_asking_if_my_child_is_home_educated

    when_i_click_continue
    then_i_see_an_error

    when_i_choose_yes
    then_i_see_the_parent_step

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_a_confirmation_page_in_clinic

    when_the_nurse_checks_the_school_moves
    then_the_nurse_should_see_one_move
    and_the_nurse_confirms_the_move

    when_the_nurse_checks_the_patient
    then_the_nurse_should_see_home_schooled
  end

  scenario "submitting a consent form with mismatched contact details warns existing parent" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    and_the_patient_has_a_parent_with_known_contact_details

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    when_i_choose_yes # home educated
    then_i_see_the_parent_step

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_a_confirmation_page_in_clinic

    then_the_existing_parent_receives_a_contact_details_mismatch_warning
  end

  scenario "Child attending a clinic is not in education" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    then_i_see_a_page_asking_if_my_child_is_home_educated

    when_i_click_continue
    then_i_see_an_error

    when_i_choose_no_they_are_not_in_education
    then_i_see_the_parent_step

    when_i_give_consent
    and_i_answer_no_to_all_the_medical_questions
    then_i_can_check_my_answers

    when_i_submit_the_consent_form
    and_i_refuse_to_answer_questions_on_ethnicity
    then_i_see_a_confirmation_page_in_clinic

    when_the_nurse_checks_the_school_moves
    then_the_nurse_should_see_no_moves

    when_the_nurse_checks_the_patient
    then_the_nurse_should_see_unknown_school
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    location = @team.generic_clinic

    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location:
      )

    @child = create(:patient, school: @team.unknown_school, session: @session)

    @school = create(:school, team: @team)
  end

  def and_an_upcoming_school_session_exists
    create(
      :session,
      :scheduled,
      team: @team,
      programmes: [@programme],
      location: @school
    )
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def and_i_fill_in_my_childs_name_and_birthday
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

  def then_i_see_a_page_asking_if_my_child_is_home_educated
    expect(page).to have_heading("Is your child home-schooled?")
  end

  def when_i_choose_no_they_go_to_a_school
    choose "No, they go to a school"
    click_on "Continue"
  end

  def when_i_choose_no_they_are_not_in_education
    choose "No, they are not in education"
    click_on "Continue"
  end

  def when_i_choose_yes
    choose "Yes"
    click_on "Continue"
  end

  def then_i_see_a_page_asking_for_the_childs_school
    expect(page).to have_heading("What school does your child go to?")
  end

  def when_i_click_continue
    click_on "Continue"
  end

  def then_i_see_an_error
    expect(page).to have_heading("There is a problem")
  end

  def when_i_choose_a_school
    select @school.name
    click_on "Continue"
  end

  def then_i_see_the_parent_step
    expect(page).to have_heading("About you")
  end

  def when_i_give_consent
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

  def then_i_see_a_confirmation_page_in_school
    expect(page).to have_content("is due to get the HPV vaccination at school")

    perform_enqueued_jobs # match consent form with patient
  end

  def then_i_see_a_confirmation_page_in_clinic
    expect(page).to have_content("is due to get the HPV vaccination")
    expect(page).not_to have_content("at school")

    perform_enqueued_jobs # match consent form with patient
    expect_email_to "jane@example.com", :consent_confirmation_clinic, :any
  end

  def when_the_nurse_checks_the_school_moves
    sign_in @team.users.first
    visit "/dashboard"

    within ".nhsuk-header__navigation" do
      click_on "School moves"
    end
  end

  def then_the_nurse_should_see_one_move
    expect(page).to have_content("School moves (1)")
    expect(page).to have_content("1 school move")
  end

  def and_the_nurse_confirms_the_move
    expect(page).to have_content(@child.full_name)
    click_on "Review"
    choose "Update record with new school"
    click_on "Update child record"
    expect(page).to have_content("Success")
    expect(page).to have_content("School moves (0)")
  end

  def then_the_nurse_should_see_no_moves
    expect(page).to have_content("There are currently no school moves.")
  end

  def when_the_nurse_checks_the_patient(in_the_school: false)
    visit sessions_path

    if in_the_school
      click_on @school.name
    else
      click_on "Community clinic"
    end

    within(".app-secondary-navigation") { click_on "Children" }
    click_on @child.full_name
  end

  def then_the_nurse_should_see_the_school
    click_on "View full child record"
    expect(page).to have_content("School#{@school.name}")
  end

  def then_the_nurse_should_see_home_schooled
    click_on "View full child record"
    expect(page).to have_content("SchoolHome-educated")
  end

  def then_the_nurse_should_see_unknown_school
    click_on "View full child record"
    expect(page).to have_content("SchoolUnknown")
  end

  def and_i_refuse_to_answer_questions_on_ethnicity
    return unless Flipper.enabled?(:ethnicity_capture)

    choose "No, skip the ethnicity questions"
    click_on "Continue"
  end

  def and_the_patient_has_a_parent_with_known_contact_details
    @existing_parent =
      create(
        :parent,
        email: "original@example.com",
        phone: "07700 900100",
        phone_receive_updates: true
      )
    create(
      :parent_relationship,
      :mother,
      patient: @child,
      parent: @existing_parent
    )
  end

  def then_the_existing_parent_receives_a_contact_details_mismatch_warning
    perform_enqueued_jobs
    expect_email_to "original@example.com",
                    :consent_unknown_contact_details_warning,
                    :any
    expect_sms_to "07700 900100", :consent_unknown_contact_details_warning, :any
  end
end
