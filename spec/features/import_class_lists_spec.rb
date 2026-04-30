# frozen_string_literal: true

describe "Import class lists" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  scenario "User uploads a file" do
    given_an_hpv_programme_is_underway

    when_i_visit_a_school_page_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    then_i_should_see_the_import_page

    when_i_continue_without_uploading_a_file
    then_i_should_see_an_error

    when_i_upload_a_malformed_csv
    then_i_should_see_an_error

    when_i_upload_a_file_with_invalid_fields
    then_i_should_see_the_imports_page_with_the_processing_flash

    when_i_go_to_the_import_page
    then_i_should_see_the_holding_page

    when_i_wait_for_the_background_job_to_complete
    and_i_refresh_the_page
    then_i_should_the_errors_page_with_invalid_fields

    when_i_go_back_to_the_upload_page
    and_i_select_the_year_groups
    and_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_patients

    when_i_go_to_the_session
    then_i_should_see_the_children_added_to_the_session
  end

  context "when PDS lookup during import is enabled" do
    scenario "User uploads a file" do
      given_an_hpv_programme_is_underway
      and_pds_lookup_during_import_is_enabled

      when_i_visit_a_school_page_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      then_i_should_see_the_import_page

      when_i_continue_without_uploading_a_file
      then_i_should_see_an_error

      when_i_upload_a_malformed_csv
      then_i_should_see_an_error

      when_i_upload_a_file_with_invalid_fields
      then_i_should_see_the_imports_page_with_the_processing_flash

      when_i_go_to_the_import_page
      then_i_should_see_the_holding_page

      when_i_wait_for_the_background_job_to_complete
      and_i_refresh_the_page
      then_i_should_the_errors_page_with_invalid_fields

      when_i_go_back_to_the_upload_page
      and_i_select_the_year_groups
      and_i_upload_a_valid_file
      then_i_should_see_the_upload
      and_i_should_see_the_patients

      when_i_go_to_the_session
      then_i_should_see_the_children_added_to_the_session
    end
  end

  def given_an_hpv_programme_is_underway
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)

    location = create(:gias_school, name: "Waterloo Road", team: @team)

    @user = @team.users.first

    @session =
      create(:session, :unscheduled, team: @team, location:, programmes:)
  end

  def and_pds_lookup_during_import_is_enabled
    Flipper.enable(:pds_search_during_import)

    stub_pds_search_to_return_a_patient(
      "9990000026",
      "family" => "Smith",
      "given" => "Jimmy",
      "birthdate" => "eq2010-01-02",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9999075320",
      "family" => "Clarke",
      "given" => "Jennifer",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9999075320",
      "family" => "Clarke",
      "given" => "Jennifer",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1AB"
    )

    stub_pds_search_to_return_a_patient(
      "9435764479",
      "family" => "Doe",
      "given" => "Mark",
      "birthdate" => "eq2010-01-03",
      "address-postalcode" => "SW1A 1AA"
    )
  end

  def when_i_visit_a_school_page_for_the_hpv_programme
    sign_in @user
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Waterloo Road"
  end

  def and_i_start_adding_children_to_the_school
    click_on "Import class lists"
  end

  def and_i_select_the_year_groups
    check "Year 8"
    check "Year 9"
    check "Year 10"
    check "Year 11"
    click_on "Continue"
  end

  def then_i_should_see_the_import_page
    expect(page).to have_content("Upload class list")
  end

  def and_i_upload_a_valid_file
    travel 1.minute

    attach_file_fixture "class_import[csv]", "class_import/valid.csv"
    click_on "Continue"

    wait_for_import_to_complete(ClassImport)
  end

  def then_i_should_see_the_patients
    expect(page).to have_content(
      "Name and NHS numberPostcodeSchoolDate of birth"
    )
    expect(page).to have_content("SMITH, Jimmy")
    expect(page).to have_content(/NHS number.*999.*000.*0018/)
    expect(page).to have_content("Date of birth 1 January 2010")
    expect(page).to have_content("Postcode SW1A 1AA")
  end

  alias_method :and_i_should_see_the_patients, :then_i_should_see_the_patients

  def when_i_click_on_upload_records
    click_on "Upload records"
  end

  def then_i_should_see_the_upload
    expect(page).to have_content("Uploaded byUSER, Test")
    expect(page).to have_content(
      "Year groupsYear 8, Year 9, Year 10, and Year 11"
    )
  end

  def when_i_click_on_the_imports_tab
    visit imports_path
  end

  def then_i_should_see_the_import
    expect(page).to have_content("1 completed import")
  end

  def then_i_should_see_the_children_added_to_the_session
    expect(page).to have_content("4 children")
  end

  def then_i_should_see_the_children
    expect(page).to have_content("4 children")
    expect(page).to have_content(
      "Name and NHS numberPostcodeSchoolDate of birth"
    )
    expect(page).to have_content("Name and NHS number SMITH, Jimmy")
    expect(page).to have_content(/NHS number.*999.*000.*0018/)
    expect(page).to have_content("Date of birth 1 January 2010")
    expect(page).to have_content("Postcode SW1A 1AA")
  end

  def when_i_continue_without_uploading_a_file
    click_on "Continue"
  end

  def then_i_should_see_an_error
    expect(page).to have_content("There is a problem")
  end

  def when_i_upload_a_malformed_csv
    attach_file_fixture "class_import[csv]", "class_import/malformed.csv"
    click_on "Continue"
  end

  def when_i_upload_a_file_with_invalid_fields
    attach_file_fixture "class_import[csv]", "class_import/invalid_fields.csv"
    click_on "Continue"
  end

  def then_i_should_the_errors_page_with_invalid_fields
    expect(page).to have_content("What your CSV file must include")
    expect(page).to have_content("Row 1")
  end

  def when_i_go_back_to_the_upload_page
    click_on "Back"

    click_on "Upload records"
    choose "Class list records"
    click_on "Continue"

    select "Waterloo Road"
    click_on "Continue"
  end

  def then_i_should_see_the_imports_page_with_the_processing_flash
    expect(page).to have_content("Import processing started")
  end

  def when_i_wait_for_the_background_job_to_complete
    Sidekiq::Job.drain_all
  end

  def then_i_should_see_the_holding_page
    expect(page).to have_css(".nhsuk-tag", text: "Processing")
  end

  def and_i_refresh_the_page
    visit current_path
  end

  def when_i_go_to_the_import_page
    click_link ClassImport.last.created_at.to_fs(:long), match: :first
  end

  def when_i_go_to_the_session
    visit session_path(@session)
  end
end
