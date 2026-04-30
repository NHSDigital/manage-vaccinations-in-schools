# frozen_string_literal: true

describe "Immunisation imports duplicates" do
  scenario "User reviews and selects between duplicate records" do
    given_an_hpv_programme_is_underway
    and_an_existing_patient_record_exists
    and_i_am_signed_in

    when_i_go_to_the_import_page
    and_i_click_on_the_upload_link
    and_i_upload_a_file_with_duplicate_records
    then_i_should_see_the_import_page_with_duplicate_records
    and_the_first_patient_should_not_be_updated_but_have_a_vaccination_record

    when_i_review_the_first_duplicate_record
    then_i_should_see_the_first_duplicate_record

    when_i_submit_the_form_without_choosing_anything
    then_i_should_see_a_validation_error

    when_i_choose_to_keep_the_duplicate_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_duplicate_record_should_be_persisted

    when_i_visit_the_import_issues_page
    and_i_review_the_second_duplicate_record
    then_i_should_see_the_second_duplicate_record

    when_i_choose_to_keep_the_previously_uploaded_record
    and_i_confirm_my_selection
    then_i_should_see_a_success_message
    and_the_second_record_should_not_be_updated

    when_i_go_to_the_import_page
    then_i_should_see_no_import_issues_with_the_count
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team =
      create(:team, :with_one_nurse, ods_code: "R1L", programmes: [@programme])

    @location = create(:gias_school, urn: "110158", name: "Eton College")
    @session =
      create(
        :session,
        team: @team,
        programmes: [@programme],
        location: @location,
        date: Date.new(2024, 5, 14)
      )
  end

  def and_an_existing_patient_record_exists
    @existing_patient =
      create(
        :patient,
        given_name: "Esmae",
        family_name: "O'Connell",
        nhs_number: "7420180008", # First row of valid_hpv.csv
        date_of_birth: Date.new(2014, 3, 29),
        gender_code: :female,
        address_postcode: "SW11 1AA",
        school: @location
      )
    @already_vaccinated_patient =
      create(
        :patient,
        given_name: "Caden",
        family_name: "Attwater",
        nhs_number: "4146825652", # Third row of valid_hpv.csv
        date_of_birth: Date.new(2012, 9, 14),
        gender_code: :male,
        address_postcode: "LE1 2DA",
        school: @location
      )
    @third_patient =
      create(
        :patient,
        given_name: "Joanna",
        family_name: "Hamilton",
        nhs_number: "2675725722", # Fourth row of valid_hpv.csv
        date_of_birth: Date.new(2012, 9, 14),
        gender_code: :female,
        address_postcode: "LE8 2DA",
        school: @location
      )
    @patient_location =
      create(
        :patient_location,
        patient: @already_vaccinated_patient,
        session: @session
      )
    @third_patient_location =
      create(:patient_location, patient: @third_patient, session: @session)
    @vaccine = @programme.vaccines.find_by(upload_name: "Gardasil9")
    @other_vaccine = @programme.vaccines.find_by(upload_name: "Cervarix")
    @batch = create(:batch, vaccine: @vaccine, number: "SomethingElse")
    @other_batch =
      create(:batch, vaccine: @other_vaccine, number: "CervarixBatch")
    @previous_vaccination_record =
      create(
        :vaccination_record,
        programme: @programme,
        performed_at: @session.dates.min,
        notes: "Foo",
        created_at: Time.zone.yesterday,
        batch: @batch,
        delivery_method: :nasal_spray,
        delivery_site: :nose,
        dose_sequence: 1,
        patient: @already_vaccinated_patient,
        vaccine: @vaccine,
        performed_by_user: nil,
        location_name: "Eton College"
      )
    @another_previous_vaccination_record =
      create(
        :vaccination_record,
        programme: @programme,
        performed_at: @session.dates.min,
        notes: "Bar",
        created_at: Time.zone.yesterday,
        batch: @other_batch,
        delivery_method: :nasal_spray,
        delivery_site: :left_arm_upper_position,
        dose_sequence: 1,
        patient: @third_patient,
        vaccine: @other_vaccine,
        performed_by_user: nil,
        location_name: "Eton College"
      )
  end

  def and_i_am_signed_in
    sign_in @team.users.first
    visit dashboard_path
  end

  def when_i_visit_the_import_issues_page
    visit imports_issues_path
  end

  def and_i_click_on_the_upload_link
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"
  end

  def and_i_upload_a_file_with_duplicate_records
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/point_of_care/valid_hpv.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def then_i_should_see_the_import_page_with_duplicate_records
    expect(page).to have_content("2 upload issues")
  end

  def when_i_choose_to_keep_the_duplicate_record
    choose "Use uploaded vaccination record"
  end

  def when_i_choose_to_keep_the_previously_uploaded_record
    choose "Keep existing vaccination record"
  end

  def when_i_submit_the_form_without_choosing_anything
    click_on "Resolve duplicate"
  end
  alias_method :and_i_confirm_my_selection,
               :when_i_submit_the_form_without_choosing_anything

  def then_i_should_see_a_success_message
    expect(page).to have_content("Record updated")
  end

  def when_i_review_the_first_duplicate_record
    find(".nhsuk-details__summary", text: "2 upload issues").click
    click_on "Review ATTWATER, Caden"
  end

  def then_i_should_see_the_first_duplicate_record
    expect(page).to have_content("Batch number123013325")
    expect(page).to have_content("Batch numberSomethingElse")
    expect(page).to have_content("MethodIntramuscular")
    expect(page).to have_content("MethodNasal spray")
    expect(page).to have_content("SiteLeft thigh")
    expect(page).to have_content("SiteNose")
  end

  def then_i_should_see_the_second_duplicate_record
    expect(page).to have_content("Batch number123013325")
    expect(page).to have_content("Batch numberCervarixBatch")
    expect(page).to have_content("MethodNasal spray")
    expect(page).to have_content("SiteLeft arm (upper position)")
    expect(page).to have_content("SiteNose")
  end

  def and_the_first_patient_should_not_be_updated_but_have_a_vaccination_record
    @existing_patient.reload
    expect(@existing_patient.given_name).to eq("Esmae")
    expect(@existing_patient.family_name).to eq("O'Connell")
    expect(@existing_patient.pending_changes).to eq({})
    expect(@existing_patient.vaccination_records.count).to eq(1)
    vaccs_record = @existing_patient.vaccination_records.first
    expect(vaccs_record.performed_at).to eq(Date.new(2024, 5, 14))
    expect(vaccs_record.delivery_method).to eq("intramuscular")
    expect(vaccs_record.delivery_site).to eq("left_buttock")
  end

  def then_i_should_see_a_validation_error
    expect(page).to have_content("There is a problem")
  end

  def and_i_review_the_second_duplicate_record
    click_on "Review HAMILTON, Joanna"
  end

  def and_the_duplicate_record_should_be_persisted
    @previous_vaccination_record.reload
    expect(@previous_vaccination_record.delivery_method).to eq("intramuscular")
    expect(@previous_vaccination_record.delivery_site).to eq("left_thigh")
    expect(@previous_vaccination_record.pending_changes).to eq({})
  end

  def and_the_second_record_should_not_be_updated
    @another_previous_vaccination_record.reload
    expect(@another_previous_vaccination_record.delivery_method).to eq(
      "nasal_spray"
    )
    expect(@another_previous_vaccination_record.delivery_site).to eq(
      "left_arm_upper_position"
    )
    expect(@another_previous_vaccination_record.pending_changes).to eq({})
  end

  def when_i_upload_the_records
    click_button "Upload records"
  end

  def then_i_should_see_the_vaccination_upload_report
    expect(page).to have_content("Vaccination report")
  end

  def when_i_go_to_the_import_page
    click_link "Manage data", match: :first
  end

  def then_i_should_see_import_issues_with_the_count
    expect(page).to have_link("Issues")
    expect(page).to have_selector(".app-count", text: "(1)").twice
  end

  def then_i_should_see_no_import_issues_with_the_count
    expect(page).to have_link("Issues")
    expect(page).to have_selector(".app-count", text: "(0")
  end
end
