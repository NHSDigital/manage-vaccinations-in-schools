# frozen_string_literal: true

describe "Parental consent given with an inexact automatic match" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Consent form matches the cohort on three of four fields" do
    stub_pds_search_to_return_no_patients

    given_an_hpv_programme_is_underway
    and_the_child_is_present_in_the_cohort

    when_a_parent_gives_consent_with_three_of_four_fields_matching_the_cohort
    and_the_nurse_checks_the_consent_responses
    then_they_see_that_the_child_has_consent
    and_they_see_consent_contact_warning_notifications
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
  end

  def and_the_child_is_present_in_the_cohort
    @child =
      create(
        :patient,
        session: @session,
        given_name: "Joanna",
        family_name: "Smith",
        date_of_birth: Date.new(2011, 1, 1),
        address_postcode: "TE1 1ST"
      )
    @parent = create(:parent, email: "eliza.smith@example.com")
    create(:parent_relationship, :mother, parent: @parent, patient: @child)
  end

  def when_a_parent_gives_consent_with_three_of_four_fields_matching_the_cohort
    visit start_parent_interface_consent_forms_path(@session, @programme)
    click_on "Start now"

    expect(page).to have_content("What is your child’s name?")
    fill_in "First name", with: "Joanna "
    fill_in "Last name", with: "Smith"
    choose "No" # Do they use a different name in school?
    click_on "Continue"

    expect(page).to have_content("What is your child’s date of birth?")
    fill_in "Day", with: "1"
    fill_in "Month", with: "1"
    fill_in "Year", with: "2011"
    click_on "Continue"

    choose "Yes, they go to this school"
    click_on "Continue"

    expect(page).to have_content("About you")
    fill_in "Full name", with: "Jane #{@child.family_name}"
    choose "Mum" # Your relationship to the child
    fill_in "Email address", with: "jane@example.com"
    click_on "Continue"

    expect(page).to have_content("Do you agree")
    choose "Yes, I agree"
    click_on "Continue"

    expect(page).to have_content("Home address") # they've moved recently
    fill_in "Address line 1", with: "1 Test Street"
    fill_in "Address line 2 (optional)", with: "2nd Floor"
    fill_in "Town or city", with: "Testville"
    fill_in "Postcode", with: "SW1A 1AA"
    click_on "Continue"

    until page.has_content?("Check and confirm")
      choose "No"
      click_on "Continue"
    end

    expect(page).to have_content("Child’s nameJoanna Smith")
    click_on "Confirm"

    if Flipper.enabled?(:ethnicity_capture)
      choose "No, skip the ethnicity questions"
      click_on "Continue"
    end

    expect(page).to have_content(
      "Joanna Smith is due to get the HPV vaccination at school"
    )
  end

  def and_the_nurse_checks_the_consent_responses
    2.times { perform_enqueued_jobs }

    sign_in @team.users.first
    visit sessions_path
    click_on "Pilot School"
    within ".app-secondary-navigation" do
      click_on "Children"
    end
  end

  def then_they_see_that_the_child_has_consent
    choose "Due vaccination"
    click_on "Update results"

    expect(page).to have_content(@child.full_name)
  end

  def and_they_see_consent_contact_warning_notifications
    click_on "SMITH, Joanna"
    click_on "Session activity and notes"
    expect(page).to have_content("Consent unknown contact details warning sent")
    expect(page).to have_content(@parent.email)
    expect(page).to have_content(@parent.phone)
    expect(page).to have_content("Consent confirmation given sent")
  end
end
