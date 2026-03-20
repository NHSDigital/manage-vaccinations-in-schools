# frozen_string_literal: true

describe "End-to-end journey" do
  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  scenario "Cohorting, session creation, verbal consent, vaccination" do
    # Homepage
    given_an_hpv_programme_is_underway
    and_i_am_a_nurse_signed_into_the_service
    then_i_should_see_the_default_dashboard_cards
    and_the_default_navigation_items
    and_the_default_service_name
    and_the_default_service_guide_link

    # Cohorting
    when_i_upload_the_cohort_import_containing_one_child
    then_i_see_that_the_cohort_has_been_uploaded

    # Session creation
    when_i_start_creating_a_new_session_by_choosing_school_and_time
    and_confirm_the_session_details
    then_i_see_the_session_page

    when_i_look_at_children_that_need_consent_responses
    then_i_see_the_children_from_the_cohort

    when_i_click_on_the_child_we_registered
    then_i_see_the_childs_details_including_the_updated_nhs_number

    # Verbal consent
    given_the_day_of_the_session_comes
    when_i_register_verbal_consent
    then_i_should_see_that_the_patient_is_ready_for_vaccination

    # Attendance
    when_i_click_on_the_register_attendance_section
    and_i_record_the_patient_in_attendance

    # Vaccination
    when_i_click_on_the_vaccination_section
    and_i_record_the_successful_vaccination
    then_i_see_that_the_child_is_vaccinated
    and_i_cant_edit_attendance

    # Activity log
    when_i_click_on_the_child_we_registered
    then_i_see_the_activity_log_link

    when_i_go_to_the_activity_log
    then_i_see_the_populated_activity_log
  end

  def given_an_hpv_programme_is_underway
    programme = Programme.hpv

    @team = create(:team, :with_one_nurse, programmes: [programme])
    @school =
      create(:gias_school, :secondary, team: @team, name: "Pilot School")
    @batch =
      create(
        :batch,
        expiry: Date.new(2024, 4, 1),
        team: @team,
        vaccine: programme.vaccines.first
      )

    create(
      :session,
      :unscheduled,
      location: @school,
      team: @team,
      programmes: [programme]
    )
  end

  def and_i_am_a_nurse_signed_into_the_service
    sign_in @team.users.first
    visit "/dashboard"
  end

  def then_i_should_see_the_default_dashboard_cards
    cards = page.all(".nhsuk-card-group__item")
    expect(cards[0].first("h2")).to have_content("Schools")
    expect(cards[1].first("h2")).to have_content("Children")
    expect(cards[2].first("h2")).to have_content("Sessions")
    expect(cards[3].first("h2")).to have_content("Vaccines")
  end

  def and_the_default_navigation_items
    navigation_items = page.all(".nhsuk-header__navigation-item")
    expect(navigation_items.count).to eq(9)
    expect(navigation_items[0]).to have_link("Schools", href: schools_path)
    expect(navigation_items[8]).to have_link(
      "Team",
      href: contact_details_team_path
    )
  end

  def and_the_default_service_name
    page_title = page.first("h1")
    service_name = page.first(".nhsuk-header__service-name")
    expect(page_title.text).to eq("Manage vaccinations in schools (Mavis)")
    expect(service_name.text).to eq("Manage vaccinations in schools")
  end

  def and_the_default_service_guide_link
    expect(page).to have_link(
      "Service guidance",
      href: "https://guide.manage-vaccinations-in-schools.nhs.uk"
    )
  end

  def when_i_upload_the_cohort_import_containing_one_child
    cohort_data = {
      "CHILD_ADDRESS_LINE_1" => "1 Test Street",
      "CHILD_ADDRESS_LINE_2" => "2nd Floor",
      "CHILD_POSTCODE" => "TE1 1ST",
      "CHILD_TOWN" => "Testville",
      "CHILD_PREFERRED_GIVEN_NAME" => "Drop Table",
      "CHILD_DATE_OF_BIRTH" => "2011-01-01",
      "CHILD_FIRST_NAME" => "Bobby",
      "CHILD_LAST_NAME" => "Tables",
      "CHILD_NHS_NUMBER" => "999 888 6678",
      "CHILD_SCHOOL_URN" => @school.urn.to_s,
      "PARENT_1_EMAIL" => "daddy.tests@example.com",
      "PARENT_1_NAME" => "Big Daddy Tests",
      "PARENT_1_PHONE" => "07123456789",
      "PARENT_1_RELATIONSHIP" => "Father",
      "PARENT_2_EMAIL" => "",
      "PARENT_2_NAME" => "",
      "PARENT_2_PHONE" => "",
      "PARENT_2_RELATIONSHIP" => ""
    }

    @registered_parents_csv =
      CSV::Table.new([CSV::Row.new(cohort_data.keys, cohort_data.values)])

    csv_file = Tempfile.new("cohort_import.csv", Rails.root.join("tmp"))
    csv_file.write(@registered_parents_csv.to_csv)
    csv_file.close

    visit imports_path
    click_on "Upload records"
    choose "Child records"
    click_on "Continue"
    attach_file "cohort_import[csv]", csv_file.path
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def then_i_see_that_the_cohort_has_been_uploaded
    expect(page).to have_content("1 imported record")
  end

  def when_i_start_creating_a_new_session_by_choosing_school_and_time
    click_on "Sessions"
    choose "Unscheduled"
    click_on "Update results"
    click_on "Pilot School"
    click_on "Edit session"

    click_on "Add session dates"
    expect(page).to have_content("When will this session be held?")

    fill_in "Day", with: "1"
    fill_in "Month", with: "3"
    fill_in "Year", with: "2024"
    click_on "Continue"
  end

  def and_confirm_the_session_details
    expect(page).to have_content("Edit session")

    expect(page).to have_content("ProgrammesHPV")
    expect(page).to have_content("Session datesFriday, 1 March 2024")
    expect(page).to have_content(
      "Consent requestsSend on Friday, 9 February 2024"
    )
    expect(page).to have_content(
      "Consent remindersSend 1 week before each session"
    )
    expect(page).to have_content("Next: Friday, 23 February 2024")

    click_on "Save changes"
  end

  def then_i_see_the_session_page
    expect(page).to have_content("Pilot School")
  end

  def when_i_look_at_children_that_need_consent_responses
    within(".app-secondary-navigation") { click_on "Children" }
    choose "Needs consent"
    click_on "Update results"
  end

  def then_i_see_the_children_from_the_cohort
    expect(page).to have_content("TABLES, Bobby")
  end

  def when_i_click_on_the_child_we_registered
    click_link "TABLES, Bobby"
  end

  def then_i_see_the_childs_details_including_the_updated_nhs_number
    click_on "View full child record"
    expect(page).to have_content(/NHS number.*999.*888.*6678/)
  end

  def given_the_day_of_the_session_comes
    travel_to(Time.zone.local(2024, 3, 1))
    sign_in @team.users.first
  end

  def when_i_register_verbal_consent
    click_link "Sessions", match: :first
    click_link "Pilot School"
    within(".app-secondary-navigation") { click_link "Children" }
    click_link "TABLES, Bobby"

    click_on "Record a new consent response"

    choose "Big Daddy Tests"
    click_button "Continue"

    # Details for parent or guardian: leave prepopulated details
    click_button "Continue"

    choose "By phone"
    click_button "Continue"

    choose "Yes, they agree"
    click_button "Continue"

    find_all(".nhsuk-fieldset")[0].choose "No"
    find_all(".nhsuk-fieldset")[1].choose "No"
    find_all(".nhsuk-fieldset")[2].choose "No"
    find_all(".nhsuk-fieldset")[3].choose "No"
    click_button "Continue"

    click_button "Confirm"

    click_link "TABLES, Bobby", match: :first
  end

  def then_i_should_see_that_the_patient_is_ready_for_vaccination
    expect(page).to have_content("ready for the vaccinator")
  end

  def when_i_click_on_the_register_attendance_section
    click_link "Pilot School"
    within(".app-secondary-navigation") { click_link "Children" }
  end

  def and_i_record_the_patient_in_attendance
    click_on "Attending"
  end

  def when_i_click_on_the_vaccination_section
    click_link "Record vaccinations"
    click_on "Update results"
  end

  def and_i_record_the_successful_vaccination
    click_link "TABLES, Bobby"

    expect(page).to have_content("Update attendance")

    within all("form")[2] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      within all("fieldset")[2] do
        choose "Yes"
        choose "Left arm (upper position)"
      end
      click_button "Continue"
    end

    choose @batch.number
    click_button "Continue"

    click_button "Confirm"
  end

  def then_i_see_that_the_child_is_vaccinated
    click_on "Pilot School"
    within(".app-secondary-navigation") { click_on "Children" }
    expect(page).not_to have_content("Not eligible")
    choose "Vaccinated", match: :first
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def and_i_cant_edit_attendance
    expect(page).not_to have_content("Update attendance")
  end

  def then_i_see_the_activity_log_link
    expect(page).to have_link "Session activity and notes"
  end

  def when_i_go_to_the_activity_log
    click_link "Session activity and notes"
  end

  def then_i_see_the_populated_activity_log
    expect(page).to have_content "Consent given by Big Daddy Tests (dad)"
  end
end
