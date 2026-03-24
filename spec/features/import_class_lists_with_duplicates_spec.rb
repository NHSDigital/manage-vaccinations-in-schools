# frozen_string_literal: true

describe "Class list imports duplicates" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  scenario "User reviews and selects between duplicate records" do
    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_existing_patient_records_exist

    when_i_visit_a_school_page_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    and_i_upload_a_file_with_duplicate_records
    then_i_should_see_the_import_page_with_duplicate_records

    when_i_review_the_first_duplicate_record
    then_i_should_see_the_first_duplicate_record
    and_i_should_not_be_able_to_keep_both_records

    when_i_submit_the_form_without_choosing_anything
    then_i_should_see_a_validation_error

    when_i_choose_to_keep_the_duplicate_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_first_record_should_be_updated

    when_i_visit_the_import_issues_page
    and_i_review_the_second_duplicate_record
    then_i_should_see_the_second_duplicate_record

    when_i_choose_to_keep_the_existing_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_second_record_should_not_be_updated

    when_i_visit_the_import_issues_page
    and_i_review_the_third_duplicate_record
    then_i_should_see_the_third_duplicate_record

    when_i_choose_to_keep_both_records
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_third_record_should_not_be_updated
    and_a_fourth_record_should_exist
  end

  context "when PDS lookup during import is enabled" do
    scenario "User reviews and selects between duplicate records" do
      given_i_am_signed_in
      and_pds_lookup_during_import_is_enabled
      and_an_hpv_programme_is_underway
      and_existing_patient_records_exist

      when_i_visit_a_school_page_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      and_i_upload_a_file_with_duplicate_records
      then_i_should_see_the_import_page_with_duplicate_records

      when_i_review_the_first_duplicate_record
      then_i_should_see_the_first_duplicate_record

      when_i_submit_the_form_without_choosing_anything
      then_i_should_see_a_validation_error

      when_i_choose_to_keep_the_duplicate_record
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_the_first_record_should_be_updated

      when_i_visit_the_import_issues_page
      and_i_review_the_second_duplicate_record
      then_i_should_see_the_second_duplicate_record

      when_i_choose_to_keep_the_existing_record
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_the_second_record_should_not_be_updated

      when_i_visit_the_import_issues_page
      and_i_review_the_third_duplicate_record
      then_i_should_see_the_third_duplicate_record

      when_i_choose_to_keep_both_records
      and_i_confirm_my_selection
      then_i_should_see_a_success_message
      and_the_third_record_should_not_be_updated
      and_a_fourth_record_should_exist_with_nhs_number
    end
  end

  def given_i_am_signed_in
    @team = create(:team, :with_one_nurse, programmes: [Programme.hpv])
    sign_in @team.users.first
  end

  def and_pds_lookup_during_import_is_enabled
    Flipper.enable(:import_search_pds)

    stub_pds_search_to_return_a_patient(
      "9990000018",
      "family" => "Smith",
      "given" => "Jimmy",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1BB"
    )

    stub_pds_search_to_return_a_patient(
      "9990000034",
      "family" => "Salles",
      "given" => "Rebecca",
      "birthdate" => "eq2010-02-03",
      "address-postalcode" => "SW1A 3BB"
    )

    stub_pds_search_to_return_a_patient(
      "9990000026",
      "family" => "Jones",
      "given" => "Sara",
      "birthdate" => "eq2010-02-02",
      "address-postalcode" => "SW1A 2BB"
    )
  end

  def and_an_hpv_programme_is_underway
    programme = Programme.hpv

    @location =
      create(:gias_school, :secondary, name: "Waterloo Road", team: @team)
    @session =
      create(
        :session,
        :unscheduled,
        team: @team,
        location: @location,
        programmes: [programme]
      )
  end

  def and_existing_patient_records_exist
    @existing_patient =
      create(
        :patient,
        given_name: "Jimmy",
        family_name: "Smith",
        nhs_number: "9990000018",
        date_of_birth: Date.new(2010, 1, 1),
        gender_code: :male,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: @location,
        session: @session
      )

    @second_patient =
      create(
        :patient,
        given_name: "Sarah",
        family_name: "Jones",
        nhs_number: "9990000026",
        date_of_birth: Date.new(2010, 2, 2),
        gender_code: :female,
        address_line_1: "10 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 2BB",
        school: @location,
        session: @session
      )

    @third_patient = # triggers 3/4 match
      create(
        :patient,
        given_name: "Jenny",
        family_name: "Salles",
        nhs_number: nil,
        address_postcode: "SW1A 3BB",
        date_of_birth: Date.new(2010, 2, 3),
        school: @location,
        session: @session
      )
  end

  def when_i_visit_a_school_page_for_the_hpv_programme
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Waterloo Road"
  end

  def when_i_visit_the_import_issues_page
    visit imports_issues_path
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

  def and_i_upload_a_file_with_duplicate_records
    attach_file_fixture "class_import[csv]", "class_import/duplicates.csv"
    click_on "Continue"
    wait_for_import_to_complete(ClassImport)
  end

  def then_i_should_see_the_import_page_with_duplicate_records
    expect(page).to have_content("3 upload issues")
  end

  def when_i_review_the_first_duplicate_record
    find(".nhsuk-details__summary", text: "3 upload issues").click
    click_on "Review SMITH, Jimmy"
  end

  def then_i_should_see_the_first_duplicate_record
    expect(page).to have_content("Address10 Downing StreetLondonSW1A 1AA")
    expect(page).to have_content("Address10 Downing StreetLondonSW1A 1BB")
  end

  def when_i_submit_the_form_without_choosing_anything
    click_on "Resolve duplicate"
  end
  alias_method :and_i_confirm_my_selection,
               :when_i_submit_the_form_without_choosing_anything

  def then_i_should_see_a_validation_error
    expect(page).to have_content("There is a problem")
  end

  def when_i_choose_to_keep_the_duplicate_record
    choose "Use uploaded child record"
  end

  def when_i_choose_to_keep_the_existing_record
    choose "Keep existing child"
  end

  def when_i_choose_to_keep_both_records
    choose "Keep both child records"
  end

  def and_i_should_not_be_able_to_keep_both_records
    expect(page).not_to have_content("Keep both child records")
  end

  def then_i_should_see_a_success_message
    expect(page).to have_content("Record updated")
  end

  def and_the_first_record_should_be_updated
    @existing_patient.reload
    expect(@existing_patient.address_postcode).to eq("SW1A 1BB")
    expect(@existing_patient.pending_changes).to eq({})
  end

  def and_i_review_the_second_duplicate_record
    click_on "Review JONES, Sarah"
  end

  def then_i_should_see_the_second_duplicate_record
    expect(page).to have_content("Full nameJONES, Sara")
    expect(page).to have_content("Full nameJONES, Sarah")
  end

  def and_the_second_record_should_not_be_updated
    @second_patient.reload
    expect(@second_patient.given_name).to eq("Sarah")
    expect(@second_patient.pending_changes).to eq({})
  end

  def and_i_review_the_third_duplicate_record
    click_on "Review SALLES, Jenny"
  end

  def then_i_should_see_the_third_duplicate_record
    expect(page).to have_content("Full nameSALLES, Jenny")
  end

  def and_the_third_record_should_not_be_updated
    @third_patient.reload
    expect(@third_patient.given_name).to eq("Jenny")
    expect(@third_patient.pending_changes).to eq({})
  end

  def and_a_fourth_record_should_exist
    expect(Patient.count).to eq(4)

    fourth_patient = Patient.find_by(nhs_number: nil, given_name: "Rebecca")
    expect(fourth_patient.family_name).to eq("Salles")
  end

  def and_a_fourth_record_should_exist_with_nhs_number
    expect(Patient.count).to eq(4)

    fourth_patient = Patient.find_by(nhs_number: "9990000034")
    expect(fourth_patient.given_name).to eq("Rebecca")
    expect(fourth_patient.family_name).to eq("Salles")
  end

  def and_a_fourth_record_should_not_exist
    expect(Patient.count).to eq(3)
  end
end
