# frozen_string_literal: true

describe "Immunisation imports" do
  around { |example| travel_to(Date.new(2025, 5, 20)) { example.run } }

  scenario "User uploads a file, views cohort and vaccination records" do
    given_an_hpv_programme_is_underway
    and_i_am_signed_in
    and_school_locations_exist
    given_a_patient_exists

    when_i_go_to_the_import_page
    then_i_should_see_the_upload_link

    when_i_click_on_the_upload_link
    then_i_should_see_the_upload_page

    when_i_continue_without_uploading_a_file
    then_i_should_see_an_error

    when_i_upload_an_invalid_file
    then_i_should_see_the_errors_page

    travel_to 1.minute.from_now # to ensure the created_at is different for the import jobs

    when_i_go_back_to_the_upload_page
    and_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_vaccination_records
    and_the_patients_should_now_be_associated_with_the_team
    and_the_newly_created_patients_should_be_archived
    and_the_existing_patients_should_not_be_archived

    when_i_click_on_a_vaccination_record
    then_i_should_see_the_vaccination_record
    and_the_patient_should_be_archived

    when_i_go_to_the_children_page
    and_i_search_for_existing_patient
    then_i_should_see_the_existing_patient
    when_i_search_for_new_patient
    then_i_should_not_see_the_new_patient
    when_i_include_archived_patients
    then_i_should_see_the_new_patient
  end

  def given_an_hpv_programme_is_underway
    programme = Programme.hpv
    @team =
      create(:team, :with_one_nurse, ods_code: "R1L", programmes: [programme])
    location = create(:gias_school, team: @team)
    @session = create(:session, programmes: [programme], location:, team: @team)
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def and_school_locations_exist
    create(:gias_school, urn: "110158")
    create(:gias_school, urn: "120026")
    create(:gias_school, urn: "144012")
  end

  def given_a_patient_exists
    @existing_patient =
      create(
        :patient,
        given_name: "Oliver",
        family_name: "Bowers",
        date_of_birth: Date.new(2010, 9, 17),
        nhs_number: "8160442742",
        session: @session,
        team: @team
      )
  end

  def when_i_go_to_the_import_page
    visit "/dashboard"

    click_on "Import", match: :first
  end

  def then_i_should_see_the_upload_link
    expect(page).to have_button("Upload records")
  end

  def when_i_click_on_the_upload_link
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"
  end

  def when_i_click_on_the_imports_tab
    click_on "Imports"
  end

  def and_i_choose_to_import_child_records
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"
  end

  def then_i_should_see_the_upload_page
    expect(page).to have_content("Upload vaccination records")
  end

  def when_i_continue_without_uploading_a_file
    click_on "Continue"
  end

  def then_i_should_see_an_error
    expect(page).to have_content("There is a problem")
  end

  def when_i_upload_an_invalid_file
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/point_of_care/invalid_rows.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def then_i_should_see_the_errors_page
    expect(page).to have_content("What your CSV file must include")
    expect(page).to have_content("Row 3")
    expect(page).to have_content("VACCINATED:")

    expect(page).to have_content("Row 3")
    expect(page).to have_content("BATCH_EXPIRY_DATE:")
    expect(page).to have_content("VACCINE_GIVEN:")
  end

  def when_i_go_back_to_the_upload_page
    click_on "Back"
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"
  end

  def and_i_upload_a_valid_file
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/point_of_care/valid_hpv.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def then_i_should_see_the_success_heading
    expect(page).to have_content("8 new vaccination records")
  end

  def and_i_should_see_the_vaccination_records
    expect(page).to have_content(
      "Full nameNHS numberDate of birthVaccination date"
    )
    expect(page).to have_content("Full name PICKLE, Chyna")
    expect(page).to have_content(/NHS number.*742.*018.*0008/)
    expect(page).to have_content("Date of birth 12 September 2010")
    expect(page).to have_content("Vaccination date 14 May 2024")
  end

  def and_the_patients_should_now_be_associated_with_the_team
    Patient.all.find_each { |patient| expect(patient.teams).to include(@team) }
  end

  def and_the_newly_created_patients_should_be_archived
    new_patient = Patient.find_by(nhs_number: "7420180008")
    expect(new_patient.archived?(team_id: @team.id)).to be true
    expect(new_patient.archive_reasons.first.type).to eq "immunisation_import"
  end

  def and_the_existing_patients_should_not_be_archived
    expect(@existing_patient.archived?(team_id: @team.id)).to be false
  end

  def when_i_go_back
    click_on "Back to check and confirm upload"
  end

  def and_i_click_on_upload_records
    click_on "Upload records"
  end

  def then_i_should_see_the_upload
    expect(page).to have_content("Uploaded byUSER, Test")
  end

  def when_i_click_on_a_vaccination_record
    find(".nhsuk-details__summary", text: "1 imported record").click
    click_on "PICKLE, Chyna"
  end

  def then_i_should_see_the_vaccination_record
    expect(page).to have_content("PICKLE, Chyna")
    expect(page).to have_content("Child")
    expect(page).to have_content("Full namePICKLE, Chyna")
    expect(page).to have_content("Vaccination details")
    expect(page).to have_content("OutcomeVaccinated")
  end

  def and_the_patient_should_be_archived
    expect(page).to have_content("Archive reasonImmunisation import")
  end

  def when_i_go_to_the_children_page
    click_on "Children", match: :first
  end

  def and_i_search_for_existing_patient
    fill_in "Search", with: @existing_patient.full_name
    click_button "Search"
  end

  def then_i_should_see_the_existing_patient
    expect(page).to have_content(@existing_patient.full_name)
  end

  def when_i_search_for_new_patient
    @new_patient = Patient.find_by(nhs_number: "7420180008")
    fill_in "Search", with: @new_patient.full_name
    click_button "Search"
  end

  def then_i_should_not_see_the_new_patient
    expect(page).not_to have_content(@new_patient.full_name)
  end

  def when_i_include_archived_patients
    find(".nhsuk-details__summary").click
    check "Archived records"
    click_button "Search"
  end

  def then_i_should_see_the_new_patient
    expect(page).to have_content(@new_patient.full_name)
  end

  alias_method :and_i_click_on_the_upload_link, :when_i_click_on_the_upload_link
end
