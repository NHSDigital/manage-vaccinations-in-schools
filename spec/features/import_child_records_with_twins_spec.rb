# frozen_string_literal: true

describe "Child record imports twins" do
  around { |example| travel_to(Date.new(2024, 12, 1)) { example.run } }

  before { Flipper.enable(:pds_search_during_import) }
  after { Flipper.disable(:pds_search_during_import) }

  scenario "User reviews and selects between duplicate records" do
    and_pds_lookup_during_import_returns_nhs_numbers

    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_an_existing_patient_record_exists

    when_i_visit_the_import_page
    and_i_start_adding_children_to_the_cohort
    and_i_upload_a_file_with_a_twin
    then_i_should_see_the_import_page_with_successful_import
    and_the_twins_should_exist
  end

  def given_i_am_signed_in
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    sign_in @team.users.first
  end

  def and_pds_lookup_during_import_returns_nhs_numbers
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
      "9449306168",
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
    @existing_patient =
      create(
        :patient,
        given_name: "John",
        family_name: "Doe",
        nhs_number: "9000000009",
        date_of_birth: Date.new(2010, 1, 3),
        gender_code: :male,
        address_line_1: "11 Downing Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: @school,
        team: @team,
        session: @session
      )
  end

  def when_i_visit_the_import_page
    visit "/"
    click_link "Import", match: :first
  end

  def and_i_start_adding_children_to_the_cohort
    click_button "Upload records"
    choose "Child records"
    click_button "Continue"
  end

  def and_i_upload_a_file_with_a_twin
    attach_file_fixture "cohort_import[csv]", "cohort_import/valid.csv"
    click_on "Continue"
    wait_for_import_to_complete(CohortImport)
  end

  def then_i_should_see_the_import_page_with_successful_import
    expect(page).to have_content("3 imported records")
    expect(Patient.count).to eq(4)
  end

  def and_the_twins_should_exist
    patient = Patient.find_by(nhs_number: "9449306168")

    expect(patient).not_to eq(@existing_patient)

    expect(patient.address_postcode).to eq("SW1A 1AA")
    expect(patient.date_of_birth).to eq(Date.new(2010, 1, 3))
    expect(patient.family_name).to eq("Doe")
    expect(patient.given_name).to eq("Mark")
    expect(patient.pending_changes).to eq({})
  end
end
