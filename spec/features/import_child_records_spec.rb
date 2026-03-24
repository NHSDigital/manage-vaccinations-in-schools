# frozen_string_literal: true

describe "Import child records" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  scenario "User uploads a file" do
    given_the_app_is_setup

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records
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

    when_it_is_a_litte_bit_later
    and_i_go_back_to_the_upload_page
    and_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_patients

    when_i_click_on_a_patient
    then_i_should_see_the_patient_details

    when_i_search_for_a_child
    then_i_should_see_only_the_child

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records
    then_i_should_see_the_import_page

    travel 1.minute # to ensure the created_at is different for the import jobs

    when_i_upload_a_valid_file_with_changes
    and_i_go_to_the_import_page
    then_i_should_see_import_issues_with_the_count
  end

  context "when PDS lookup during import is enabled" do
    scenario "User uploads a file" do
      given_the_app_is_setup
      and_pds_lookup_during_import_is_enabled

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records
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

      when_it_is_a_litte_bit_later
      and_i_go_back_to_the_upload_page
      and_i_upload_a_valid_file
      then_i_should_see_the_upload
      and_i_should_see_the_patients

      when_i_click_on_a_patient
      then_i_should_see_the_patient_details

      when_i_search_for_a_child
      then_i_should_see_only_the_child

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records
      then_i_should_see_the_import_page

      travel 1.minute # to ensure the created_at is different for the import jobs

      when_i_upload_a_valid_file_with_changes
      and_i_go_to_the_import_page
      then_i_should_see_import_issues_with_the_count
    end

    scenario "Keep both records assigns changesets and PDS search results to the new patient" do
      given_the_app_is_setup
      and_pds_lookup_during_import_is_enabled
      stub_pds_search_to_return_no_patients
      and_an_existing_patient_record_exists_with_same_name_and_dob

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records
      and_i_upload_a_file_with_duplicate_except_for_postcode

      when_i_review_the_duplicate_record
      and_i_choose_to_keep_both_records
      and_i_confirm_my_selection
      then_i_should_see_a_success_message

      then_the_changeset_should_belong_to_the_new_patient
      and_the_pds_search_results_should_belong_to_the_new_patient
      and_the_import_screen_should_link_to_the_new_patient
    end
  end

  def given_the_app_is_setup
    programmes = [Programme.hpv, Programme.menacwy, Programme.td_ipv]

    @team = create(:team, :with_one_nurse, programmes:)

    create(:gias_school, urn: "123456", team: @team)
    @user = @team.users.first
  end

  def and_pds_lookup_during_import_is_enabled
    Flipper.enable(:import_search_pds)

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

  def when_i_visit_the_import_page
    sign_in @user
    visit "/dashboard"
    click_on "Import", match: :first
  end

  def and_i_choose_to_import_child_records
    click_on "Upload records"
    choose "Child records"
    click_on "Continue"
  end

  def then_i_should_see_the_import_page
    expect(page).to have_content("Upload child records")
  end

  def and_i_upload_a_valid_file
    attach_file_fixture "cohort_import[csv]", "cohort_import/valid.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def and_i_should_see_the_patients
    expect(page).to have_content(
      "Name and NHS numberPostcodeSchoolDate of birth"
    )
    expect(page).to have_content("SMITH, Jimmy")
    expect(page).to have_content(/NHS number.*999.*000.*0018/)
    expect(page).to have_content("Date of birth 1 January 2010")
    expect(page).to have_content("Postcode SW1A 1AA")
  end

  def when_i_click_on_a_patient
    find(".nhsuk-details__summary", text: "3 imported records").click
    click_on "DOE, Mark"
  end

  def then_i_should_see_the_patient_details
    expect(page).to have_content("Child record")
    expect(page).to have_content("DOE, Mark")
  end

  def then_i_should_see_the_upload
    expect(page).to have_content("Uploaded byUSER, Test")
  end

  def when_i_search_for_a_child
    click_on "Children", match: :first
    fill_in "Search", with: "DOE, Mark"
    click_on "Search"
  end

  def then_i_should_see_only_the_child
    expect(page).to have_content("1 child")
    expect(page).to have_content("DOE, Mark")
  end

  def when_i_continue_without_uploading_a_file
    click_on "Continue"
  end

  def then_i_should_see_an_error
    expect(page).to have_content("There is a problem")
  end

  def when_i_upload_a_malformed_csv
    attach_file_fixture "cohort_import[csv]", "cohort_import/malformed.csv"
    click_on "Continue"
  end

  def when_i_upload_a_file_with_invalid_fields
    attach_file_fixture "cohort_import[csv]", "cohort_import/invalid_fields.csv"
    click_on "Continue"
  end

  def then_i_should_the_errors_page_with_invalid_fields
    expect(page).to have_content(
      "How to format your Mavis CSV file for child records"
    )
    expect(page).to have_content("Row 2")
  end

  def when_it_is_a_litte_bit_later
    travel_to(1.minute.from_now) # so the imports are in a deterministic order
  end

  def and_i_go_back_to_the_upload_page
    click_on "Back"
    click_on "Upload records"
    choose "Child records"
    click_on "Continue"
  end

  def then_i_should_see_the_imports_page_with_the_processing_flash
    expect(page).to have_content("Import processing started")
  end

  def when_i_wait_for_the_background_job_to_complete
    perform_enqueued_jobs(only: ProcessImportJob)
    perform_enqueued_jobs(only: PDSCascadingSearchJob)
    perform_enqueued_jobs(only: ProcessPatientChangesetJob)
  end

  def then_i_should_see_the_holding_page
    expect(page).to have_css(".nhsuk-tag", text: "Processing")
  end

  def and_i_refresh_the_page
    visit current_path
  end

  def when_i_go_to_the_import_page
    click_on_most_recent_import(CohortImport)
  end

  def when_i_upload_a_valid_file_with_changes
    attach_file_fixture "cohort_import[csv]",
                        "cohort_import/valid_with_changes.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def and_i_go_to_the_import_page
    click_on "Import", match: :first
  end

  def then_i_should_see_import_issues_with_the_count
    expect(page).to have_link("Issues")
    expect(page).to have_selector(".app-count", text: "(1)").twice
  end

  def and_an_existing_patient_record_exists_with_same_name_and_dob
    @existing_patient =
      create(
        :patient,
        given_name: "Taylor",
        family_name: "Reed",
        nhs_number: nil,
        date_of_birth: Date.new(2010, 1, 1),
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: Location.find_by!(urn: "123456")
      )
  end

  def and_i_upload_a_file_with_duplicate_except_for_postcode
    attach_file_fixture "cohort_import[csv]",
                        "cohort_import/duplicate_except_postcode.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def when_i_review_the_duplicate_record
    find(".nhsuk-details__summary", text: /1 upload issue/).click
    click_on "Review"
  end

  def and_i_choose_to_keep_both_records
    choose "Keep both child records"
  end

  def and_i_confirm_my_selection
    click_on "Resolve duplicate"
  end

  def then_i_should_see_a_success_message
    expect(page).to have_content("Record updated")
  end

  def and_the_import_screen_should_link_to_the_new_patient
    find(".nhsuk-details__summary", text: /imported record/i).click

    expect(page).to have_link("REED, Taylor", href: patient_path(new_patient))
  end

  def then_the_changeset_should_belong_to_the_new_patient
    import = CohortImport.order(:created_at).last
    changeset = import.changesets.from_file.sole
    expect(changeset.reload.patient_id).to eq(new_patient.id)
  end

  def and_the_pds_search_results_should_belong_to_the_new_patient
    import = CohortImport.order(:created_at).last

    results =
      PDSSearchResult.where(import_type: "CohortImport", import_id: import.id)

    expect(results.pluck(:patient_id).uniq).to eq([new_patient.id])
  end

  def new_patient
    Patient
      .where(given_name: "Taylor", family_name: "Reed")
      .where.not(id: @existing_patient.id)
      .sole
  end
end
