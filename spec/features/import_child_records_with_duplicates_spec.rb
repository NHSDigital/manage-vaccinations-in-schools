# frozen_string_literal: true

describe "Child record imports duplicates" do
  around do |example|
    # to ensure the age calculation stays correct
    travel_to Time.zone.local(2024, 12, 1) do
      example.run
    end
  end

  scenario "User reviews and selects between duplicate records" do
    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_an_existing_patient_record_exists

    when_i_visit_the_import_page
    and_i_start_adding_children_to_the_cohort
    and_i_upload_a_file_with_duplicate_records
    then_i_should_see_the_import_page_with_duplicate_records

    when_i_review_the_first_duplicate_record
    then_i_should_see_the_first_duplicate_record

    when_i_submit_the_form_without_choosing_anything
    then_i_should_see_a_validation_error

    when_i_choose_to_keep_the_duplicate_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_i_should_return_to_the_import_page
    and_the_first_duplicate_record_should_be_persisted

    when_i_visit_the_import_issues_page
    and_i_review_the_second_duplicate_record
    then_i_should_see_the_second_duplicate_record

    when_i_choose_to_keep_the_previously_uploaded_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_second_record_should_not_be_updated

    when_i_visit_the_import_issues_page
    and_i_review_the_third_duplicate_record
    then_i_should_see_the_third_duplicate_record

    when_i_choose_to_keep_both_records
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_third_record_should_be_persisted
    and_a_new_patient_record_should_be_created

    when_i_go_to_the_import_page
    then_i_should_see_no_import_issues_with_the_count

    when_i_go_to_the_fourth_uploaded_record
    then_i_should_see_the_address_is_updated
  end

  context "when PDS lookup during import is enabled" do
    scenario "User reviews and selects between duplicate records" do
      given_i_am_signed_in
      and_pds_lookup_during_import_is_enabled
      and_an_hpv_programme_is_underway
      and_an_existing_patient_record_exists

      when_i_visit_the_import_page
      and_i_start_adding_children_to_the_cohort
      and_i_upload_a_file_with_duplicate_records
      then_i_should_see_the_import_page_with_duplicate_records

      when_i_review_the_first_duplicate_record
      then_i_should_see_the_first_duplicate_record

      when_i_submit_the_form_without_choosing_anything
      then_i_should_see_a_validation_error

      when_i_choose_to_keep_the_duplicate_record
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_i_should_return_to_the_import_page
      and_the_first_duplicate_record_should_be_persisted

      when_i_visit_the_import_issues_page
      and_i_review_the_second_duplicate_record
      then_i_should_see_the_second_duplicate_record

      when_i_choose_to_keep_the_previously_uploaded_record
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_the_second_record_should_not_be_updated

      when_i_visit_the_import_issues_page
      and_i_review_the_third_duplicate_record
      then_i_should_see_the_third_duplicate_record

      when_i_choose_to_keep_both_records
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_the_third_record_should_be_persisted
      and_a_new_patient_record_should_be_created

      when_i_go_to_the_import_page
      then_i_should_see_no_import_issues_with_the_count

      when_i_go_to_the_fourth_uploaded_record
      then_i_should_see_the_address_is_updated
    end
  end

  scenario "Patient is archived after upload but before duplicate review" do
    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_an_existing_patient_record_exists

    when_i_visit_the_import_page
    and_i_start_adding_children_to_the_cohort
    and_i_upload_a_file_with_duplicate_records
    then_i_should_see_the_import_page_with_duplicate_records

    given_i_archive_the_patient_record
    when_i_go_to_the_import_page
    then_i_should_see_no_import_issues_with_the_count
  end

  scenario "SearchVaccinationRecordsInNHSJob is enqueued during duplicate resolution" do
    given_i_am_signed_in
    and_the_required_feature_flags_are_enabled
    and_an_hpv_programme_is_underway
    and_matching_patient_records_exist_with_different_nhs_numbers

    when_i_visit_the_import_page
    and_i_start_adding_children_to_the_cohort
    and_i_upload_a_file_with_duplicate_records
    then_i_should_see_the_import_page_with_duplicate_records

    when_i_review_the_first_duplicate_record
    and_i_choose_to_keep_the_duplicate_record
    and_i_confirm_my_selection
    then_search_vaccination_records_in_nhs_job_should_be_enqueued
    and_i_should_return_to_the_import_page

    when_i_visit_the_import_issues_page
    and_i_review_the_second_duplicate_record_jimmy
    and_i_choose_to_keep_the_previously_uploaded_record
    and_i_confirm_my_selection
    then_search_vaccination_records_in_nhs_job_should_be_enqueued_for_second_patient
  end

  def given_i_am_signed_in
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    sign_in @team.users.first
  end

  def and_pds_lookup_during_import_is_enabled
    return unless ENV["PDS_LOOKUP_DURING_IMPORT"] == "1"

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

  def and_an_hpv_programme_is_underway
    @school = create(:gias_school, urn: "123456", team: @team)

    @session =
      create(:session, team: @team, location: @school, programmes: [@programme])
  end

  def and_an_existing_patient_record_exists
    @first_patient =
      create(
        :patient,
        given_name: "Jennifer",
        family_name: "Clarke",
        nhs_number: "9990000018", # First row of valid_with_duplicates.csv
        date_of_birth: Date.new(2010, 1, 1),
        gender_code: :female,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1AA",
        school: nil, # Unknown school, should be silently updated
        session: @session
      )

    @second_patient =
      create(
        :patient,
        given_name: "James", # The upload will change this to Jimmy
        family_name: "Smith",
        nhs_number: "9990000026", # Second row of valid_with_duplicates.csv
        date_of_birth: Date.new(2010, 1, 2),
        gender_code: :male,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1AA",
        school: @school,
        session: @session
      )

    @third_patient =
      create(
        :patient,
        given_name: "Mark", # 3/4 match to third row of valid_with_duplicates.csv on first name, last name and postcode
        family_name: "Doe",
        nhs_number: nil,
        date_of_birth: Date.new(2013, 3, 3), # different date of birth
        gender_code: :male,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: @school,
        session: @session
      )

    @fourth_patient =
      create(
        :patient,
        given_name: "Catherine",
        family_name: "Ebury",
        nhs_number: "9435807194", # Fourth row of valid_with_duplicates.csv
        date_of_birth: Date.new(2010, 1, 1),
        gender_code: :female,
        address_line_1: "11 Downing Street", # Different address line, should be silently updated
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1AA", # Same postcode as valid_with_duplicates.csv
        school: nil,
        year_group: 10,
        session: @session
      )
  end

  def when_i_visit_the_import_page
    visit "/"
    click_link "Import", match: :first
  end

  def when_i_visit_the_import_issues_page
    visit imports_issues_path
  end

  def and_i_start_adding_children_to_the_cohort
    click_button "Upload records"
    choose "Child records"
    click_button "Continue"
  end

  def and_i_upload_a_file_with_duplicate_records
    attach_file_fixture "cohort_import[csv]",
                        "cohort_import/valid_with_duplicates.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def then_i_should_see_the_import_page_with_duplicate_records
    expect(page).to have_content("Imports (3)")
  end

  def given_i_archive_the_patient_record
    PatientArchiver.call(
      patient: @first_patient,
      team: @team,
      type: :imported_in_error
    )
    PatientArchiver.call(
      patient: @second_patient,
      team: @team,
      type: :imported_in_error
    )
    PatientArchiver.call(
      patient: @third_patient,
      team: @team,
      type: :imported_in_error
    )
  end

  def when_i_choose_to_keep_the_duplicate_record
    choose "Use uploaded child record"
  end
  alias_method :and_i_choose_to_keep_the_duplicate_record,
               :when_i_choose_to_keep_the_duplicate_record

  alias_method :and_i_choose_to_keep_the_duplicate_record,
               :when_i_choose_to_keep_the_duplicate_record

  def when_i_choose_to_keep_both_records
    choose "Keep both child records"
  end

  def when_i_choose_to_keep_the_previously_uploaded_record
    choose "Keep existing child"
  end

  alias_method :and_i_choose_to_keep_the_previously_uploaded_record,
               :when_i_choose_to_keep_the_previously_uploaded_record

  alias_method :and_i_choose_to_keep_the_previously_uploaded_record,
               :when_i_choose_to_keep_the_previously_uploaded_record

  def when_i_submit_the_form_without_choosing_anything
    click_on "Resolve duplicate"
  end
  alias_method :and_i_confirm_my_selection,
               :when_i_submit_the_form_without_choosing_anything

  def then_i_should_see_a_success_message
    expect(page).to have_content("Record updated")
  end

  def and_i_should_return_to_the_import_page
    cohort_import = CohortImport.order(:created_at).last
    expect(page).to have_current_path(cohort_import_path(cohort_import))
  end

  def when_i_review_the_first_duplicate_record
    find(".nhsuk-details__summary", text: "3 upload issues").click
    click_on "Review CLARKE, Jennifer"
  end

  def then_i_should_see_the_first_duplicate_record
    expect(page).to have_content("Date of birth1 January 2010 (aged 14)")
    expect(page).to have_content("Address10 Downing StreetLondonSW11 1AA")
    expect(page).to have_content("Address10 Downing StreetLondonSW1A 1AA")
  end

  def then_i_should_see_the_second_duplicate_record
    expect(page).to have_content("Full nameSMITH, James")
    expect(page).to have_content("Full nameSMITH, Jimmy")
    expect(page).to have_content("Address10 Downing StreetLondonSW11 1AA")
    expect(page).to have_content("Address10 Downing StreetLondonSW1A 1AA")
  end

  def then_i_should_see_a_validation_error
    expect(page).to have_content("There is a problem")
  end

  def and_i_review_the_second_duplicate_record
    click_on "Review SMITH, James"
  end

  def and_i_review_the_second_duplicate_record_jimmy
    click_on "Review SMITH, Jimmy"
  end

  def and_the_first_duplicate_record_should_be_persisted
    @first_patient.reload
    expect(@first_patient.given_name).to eq("Jennifer")
    expect(@first_patient.family_name).to eq("Clarke")
    expect(@first_patient.pending_changes).to eq({})
  end

  def and_the_second_record_should_not_be_updated
    @second_patient.reload
    expect(@second_patient.given_name).to eq("James")
    expect(@second_patient.family_name).to eq("Smith")
    expect(@second_patient.pending_changes).to eq({})
  end

  def and_the_third_record_should_be_persisted
    @third_patient.reload
    expect(@third_patient.given_name).to eq("Mark")
    expect(@third_patient.family_name).to eq("Doe")
    expect(@third_patient.pending_changes).to eq({})
  end

  def and_a_new_patient_record_should_be_created
    expect(Patient.count).to eq(5)

    patient = Patient.last
    expect(patient.given_name).to eq("Mark")
    expect(patient.family_name).to eq("Doe")
    expect(patient.pending_changes).to eq({})
    expect(patient.school).to eq(@school)
    expect(patient.date_of_birth).to eq(Date.new(2010, 1, 3))
    expect(patient.gender_code).to eq("male")
    expect(patient.address_postcode).to eq("SW1A 1AA")
    expect(patient.nhs_number).to be_nil
    expect(patient.sessions.count).to eq(1)

    session = patient.sessions.first
    expect(session).to eq(@session)
  end

  def and_i_review_the_third_duplicate_record
    click_on "Review DOE, Mark"
  end

  def then_i_should_see_the_third_duplicate_record
    expect(page).to have_content("Full nameDOE, Mark")
    expect(page).to have_content("Date of birth3 January 2010 (aged 14)")
    expect(page).to have_content("Date of birth3 March 2013 (aged 11)")
    expect(page).to have_content("Year groupYear 10, ")
    expect(page).to have_content("Year groupYear 8, ")
  end

  def when_i_go_to_the_import_page
    click_link "Import", match: :first
  end

  def then_i_should_see_import_issues_with_the_count
    expect(page).to have_content("Imports (1)")
    expect(page).to have_link("Issues")
    expect(page).to have_selector(".app-count", text: "(1)")
  end

  def then_i_should_see_no_import_issues_with_the_count
    expect(page).to have_content("Imports (0)")
    expect(page).to have_link("Issues")
    expect(page).to have_selector(".app-count", text: "(0)")
  end

  def when_i_go_to_the_fourth_uploaded_record
    visit patient_path(@fourth_patient)
  end

  def then_i_should_see_the_address_is_updated
    expect(page).to have_content("10 Downing Street")
    expect(page).not_to have_content("11 Downing Street")
  end

  def and_the_required_feature_flags_are_enabled
    Flipper.enable(:imms_api_integration)
    Flipper.enable(:imms_api_search_job, @programme)
  end

  def and_matching_patient_records_exist_with_different_nhs_numbers
    @first_patient =
      create(
        :patient,
        given_name: "Jennifer",
        family_name: "Clarke",
        nhs_number: nil, # 9990000018 in valid_with_duplicates.csv, will raise a duplicate to review
        date_of_birth: Date.new(2010, 1, 1),
        gender_code: :female,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1AA",
        school: nil,
        session: @session
      )

    @second_patient =
      create(
        :patient,
        given_name: "Jimmy",
        family_name: "Smith",
        nhs_number: nil, # 999 000 0026 in valid_with_duplicates.csv, will raise a duplicate to review
        date_of_birth: Date.new(2010, 1, 2),
        gender_code: :male,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1AA",
        school: @school,
        session: @session
      )

    @third_patient =
      create(
        :patient,
        given_name: "Mark",
        family_name: "Doe",
        nhs_number: "9999075320", # nil in valid_with_duplicates.csv, will be implicitly accepted
        date_of_birth: Date.new(2010, 1, 3),
        gender_code: :male,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: @school,
        session: @session
      )
  end

  def then_search_vaccination_records_in_nhs_job_should_be_enqueued
    # When we keep the duplicate record and NHS number changes, SearchVaccinationRecordsInNHSJob should be enqueued
    expect(SearchVaccinationRecordsInNHSJob).to have_enqueued_sidekiq_job.with(
      @first_patient.id
    )
  end

  def then_search_vaccination_records_in_nhs_job_should_be_enqueued_for_second_patient
    # The second patient should have NHS number changes and SearchVaccinationRecordsInNHSJob should be enqueued
    expect(
      SearchVaccinationRecordsInNHSJob
    ).not_to have_enqueued_sidekiq_job.with(@second_patient.id)
  end
end
