# frozen_string_literal: true

describe "Import child records" do
  after { Flipper.disable(:import_choose_academic_year) }

  scenario "User uploads a file during preparation period" do
    given_today_is_the_start_of_the_2023_24_preparation_period
    and_the_app_is_setup

    then_i_should_be_in_the_preparation_period

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records
    then_i_should_see_the_import_page

    when_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_patients
  end

  scenario "User uploads a file during preparation period (not including current year)" do
    given_today_is_the_start_of_the_2023_24_preparation_period
    and_i_can_choose_the_academic_year_on_import
    and_the_app_is_setup
    then_i_should_be_in_the_preparation_period

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records(choose_academic_year: true)
    then_i_should_see_the_import_page

    when_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_patients
  end

  scenario "User uploads a file during preparation period (including current year)" do
    given_today_is_the_start_of_the_2024_25_preparation_period
    and_i_can_choose_the_academic_year_on_import
    and_the_app_is_setup
    then_i_should_be_in_the_preparation_period

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records(choose_academic_year: true)
    then_i_should_see_the_import_page

    when_i_upload_a_valid_file
    then_i_should_see_the_upload
    and_i_should_see_the_patients
  end

  context "when PDS lookup during import and review screen is enabled" do
    scenario "User uploads a file during preparation period" do
      given_today_is_the_start_of_the_2023_24_preparation_period
      and_the_app_is_setup
      and_pds_lookup_during_import_is_enabled

      then_i_should_be_in_the_preparation_period

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records
      then_i_should_see_the_import_page

      when_i_upload_a_valid_file
      then_i_should_see_the_upload
      and_i_should_see_the_patients
    end

    scenario "User uploads a file during preparation period (not including current year)" do
      given_today_is_the_start_of_the_2023_24_preparation_period
      and_i_can_choose_the_academic_year_on_import
      and_the_app_is_setup
      and_pds_lookup_during_import_is_enabled
      then_i_should_be_in_the_preparation_period

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records(choose_academic_year: true)
      then_i_should_see_the_import_page

      when_i_upload_a_valid_file
      then_i_should_see_the_upload
      and_i_should_see_the_patients
    end

    scenario "User uploads a file during preparation period (including current year)" do
      given_today_is_the_start_of_the_2024_25_preparation_period
      and_i_can_choose_the_academic_year_on_import
      and_the_app_is_setup
      and_pds_lookup_during_import_is_enabled
      then_i_should_be_in_the_preparation_period

      when_i_visit_the_import_page
      and_i_choose_to_import_child_records(choose_academic_year: true)
      then_i_should_see_the_import_page

      when_i_upload_a_valid_file
      then_i_should_see_the_upload
      and_i_should_see_the_patients
    end
  end

  def given_today_is_the_start_of_the_2023_24_preparation_period
    travel_to(Date.new(2022, 8, 1))
  end

  def given_today_is_the_start_of_the_2024_25_preparation_period
    travel_to(Date.new(2023, 8, 1))
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

  def and_i_can_choose_the_academic_year_on_import
    Flipper.enable(:import_choose_academic_year)
  end

  def and_the_app_is_setup
    programmes = [Programme.hpv, Programme.menacwy, Programme.td_ipv]

    @team = create(:team, :with_one_nurse, programmes:)
    @school = create(:school, urn: "123456", team: @team)
    @generic_clinic = @team.generic_clinic
    @user = @team.users.first

    [AcademicYear.current, AcademicYear.pending].each do |academic_year|
      @school.attach_to_team!(@team, academic_year:)
      @school.import_year_groups_from_gias!(academic_year:)
      @school.import_default_programme_year_groups!(programmes, academic_year:)

      @generic_clinic.attach_to_team!(@team, academic_year:)
      @generic_clinic.import_year_groups!(
        Location::YearGroup::DEFAULT_VALUE_RANGE,
        academic_year:,
        source: "generic_location_factory"
      )
      @generic_clinic.import_default_programme_year_groups!(
        programmes,
        academic_year:
      )
    end
  end

  def then_i_should_be_in_the_preparation_period
    expect(AcademicYear.pending).to be > AcademicYear.current
  end

  def when_i_visit_the_import_page
    sign_in @user
    visit "/dashboard"
    click_on "Import", match: :first
  end

  def and_i_choose_to_import_child_records(choose_academic_year: false)
    click_on "Upload records"

    # Type of records
    choose "Child records"
    click_on "Continue"

    if choose_academic_year
      # Include current academic year
      choose "2022 to 2023"
      click_on "Continue"
    end
  end

  def then_i_should_see_the_import_page
    expect(page).to have_content("Upload child records")
  end

  def when_i_upload_a_valid_file
    attach_file_fixture "cohort_import[csv]", "cohort_import/valid.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
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
  end

  def then_i_should_see_the_import
    expect(page).to have_content("1 completed import")
  end
end
