# frozen_string_literal: true

describe "Triage" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "nurse can triage after importing historical vaccinations" do
    given_a_td_ipv_programme_with_a_session
    and_i_am_signed_in_as_a_nurse

    when_i_go_to_the_dashboard
    and_i_upload_historical_vaccination_records
    then_i_see_the_completed_upload

    when_i_go_the_school
    and_i_upload_the_class_list
    then_i_see_the_completed_upload

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_see_no_patients_needing_triage

    when_i_go_the_session
    and_the_parent_gives_consent
    then_i_see_one_patient_needing_triage
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_triage
  end

  def given_a_td_ipv_programme_with_a_session
    @programme = Programme.td_ipv

    team = create(:team, programmes: [@programme])
    @user = create(:nurse, teams: [team])

    location = create(:gias_school, :secondary, urn: 123_456, team:)

    @session =
      create(
        :session,
        date: 1.week.from_now.to_date,
        team:,
        programmes: [@programme],
        location:
      )
  end

  def and_i_am_signed_in_as_a_nurse
    sign_in @user
  end

  def when_i_go_to_the_dashboard
    visit dashboard_path
  end

  def and_i_upload_historical_vaccination_records
    click_on "Manage data", match: :first
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"

    attach_file_fixture "immunisation_import[csv]",
                        "td_ipv/vaccination_records.csv"
    click_on "Continue"

    wait_for_import_to_complete(ImmunisationImport)
  end

  def then_i_see_the_completed_upload
    expect(page).to have_content("Completed")
  end

  def when_i_go_the_school
    click_on "Schools", match: :first
    click_on @session.location.name
  end

  def and_i_upload_the_class_list
    click_on "Import class lists"

    check "Year 9"
    click_on "Continue"

    attach_file_fixture "class_import[csv]", "td_ipv/class_list.csv"
    click_on "Continue"

    wait_for_import_to_complete(ClassImport)
  end

  def when_i_go_the_session
    click_on "Sessions", match: :first
    choose "Scheduled"
    click_on "Update results"
    click_on @session.location.name
  end

  def then_i_see_one_patient_needing_consent
    within(".app-secondary-navigation") { click_on "Children" }

    choose "Needs consent"
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def and_i_see_no_patients_needing_triage
    within(".app-secondary-navigation") { click_on "Children" }

    choose "Needs triage"
    click_on "Update results"

    expect(page).to have_content("No children matching search criteria found")
  end

  def and_the_parent_gives_consent
    create(:consent, :given, patient: Patient.first, programme: @programme)
    PatientStatusUpdater.call(patient: @patient)

    page.refresh
  end

  def then_i_see_one_patient_needing_triage
    within(".app-secondary-navigation") { click_on "Children" }

    choose "Needs triage"
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def and_i_click_on_the_patient
    click_on "PICKLE, Chyna"
  end

  def then_i_see_the_patient_needs_triage
    expect(page).to have_content("Needs triage")
    expect(page).to have_content(
      "Incomplete vaccination history for Td/IPV. Check if the child needs another dose."
    )
  end
end
