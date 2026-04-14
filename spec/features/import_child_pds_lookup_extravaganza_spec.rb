# frozen_string_literal: true

describe "Import child records" do
  let(:today) { Time.zone.local(2025, 9, 1, 12, 0, 0) }

  around { |example| travel_to(today) { example.run } }

  scenario "PDS lookup extravaganza with multiple patient scenarios" do
    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_an_existing_patient_record_exists

    when_i_visit_the_import_page
    and_pds_lookups_dont_return_any_matches
    and_i_upload_import_file("pds_extravaganza_invalid.csv")
    then_i_should_see_the_import_failed

    when_i_visit_the_import_page
    and_pds_lookup_during_import_is_enabled
    and_i_upload_import_file("pds_extravaganza_invalid.csv")
    then_i_should_see_the_import_is_invalid

    when_i_visit_the_import_page
    and_pds_lookup_during_import_is_enabled
    and_i_upload_import_file("pds_extravaganza.csv")
    then_i_should_see_the_import_page
    and_i_should_see_correct_patient_counts

    # Case 1: Patient with existing NHS number (Albert) - nothing should happen
    and_i_see_the_patient_uploaded_with_nhs_number
    and_parents_are_created_for_albert
    when_i_click_on_alberts_pds_history
    then_i_see_the_pds_lookup_history

    # Case 2: Existing patient without NHS number (Betty) - should not show duplicate review
    when_i_go_back_to_the_import_page
    then_i_do_not_see_an_import_review_for_the_first_patient_uploaded_without_nhs_number
    when_i_click_on_the_patient_without_review
    then_i_see_the_new_patient_has_an_nhs_number
    and_betty_has_correct_parent_relationships

    # Case 3: Existing patient with NHS number (Catherine) - should show duplicate review
    when_i_go_back_to_the_import_page
    then_i_see_an_import_review_for_the_second_patient_uploaded_without_nhs_number
    when_i_click_review_for("WILLIAMS, Catherine")
    then_i_see_both_records_have_an_nhs_number
    and_i_see_address_differences_for_review
    and_i_do_not_see_the_option_to_keep_both
    when_i_use_duplicate_record_during_merge
    then_the_existing_patient_has_an_nhs_number_in_mavis
    and_catherine_parents_are_handled_correctly

    # Case 4: New patient without NHS number (Charlie) - should be created with NHS number from PDS
    when_i_go_back_to_the_import_page
    when_i_click_on_new_patient_uploaded_without_an_nhs_number
    then_i_see_the_new_patient_now_has_an_nhs_number
    and_charlie_has_no_parents_as_expected

    # Case 5: Home educated patient (Emma) - test school move handling
    when_i_go_back_to_the_import_page
    when_i_click_on_home_educated_patient
    then_i_see_home_educated_patient_details
    and_emma_has_correct_parent_data

    # Case 6: Patient with parent but no relationship specified (Oliver)
    when_i_go_back_to_the_import_page
    when_i_click_on_patient_with_unknown_relationship
    then_i_see_patient_with_unknown_relationship_details
    and_oliver_has_unknown_relationship_parent

    # Case 7: Patient that matches existing exactly (Oliver)
    when_i_go_back_to_the_import_page
    then_i_see_one_record_is_an_exact_match

    # Case 8: Patient uploaded with incorrect NHS number (Lucy)
    when_i_go_back_to_the_import_page
    then_i_see_an_nhs_discrepancy
    and_lucy_has_the_pds_nhs_number

    # Case 9: Patient uploaded with NHS number, PDS returns nothing (Maia) - patient created with uploaded number
    and_there_is_an_import_review_for_maia
    when_i_review_and_accept_duplicate_maia_record
    then_maia_has_the_uploaded_nhs_number
    and_maia_has_multiple_pds_search_results

    then_school_moves_are_created_appropriately

    and_all_parent_relationships_are_established
    and_import_counts_are_correct
  end

  scenario "PDS lookup extravaganza with class lists" do
    given_i_am_signed_in
    and_an_hpv_programme_is_underway
    and_an_existing_patient_records_exist_in_school
    and_pds_lookup_during_import_is_enabled

    when_i_visit_a_school_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups

    when_i_upload_a_valid_file
    then_i_should_see_the_import_page

    and_i_should_see_no_duplicate_reviews
    and_the_registration_on_albert_should_be_set
    and_school_move_created_for_patient_not_in_import
  end

  def given_i_am_signed_in
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    sign_in @team.users.first
  end

  def and_an_hpv_programme_is_underway
    @school =
      create(
        :gias_school,
        urn: "123456",
        name: "Waterloo Road",
        gias_year_groups: [7, 8, 9, 10],
        team: @team
      )
    @clinic = @team.generic_clinic

    @session =
      create(:session, team: @team, location: @school, programmes: [@programme])
    @clinic_session =
      create(:session, team: @team, location: @clinic, programmes: [@programme])
  end

  def and_an_existing_patient_record_exists
    @existing_patient_uploaded_with_nhs_number =
      create(
        :patient,
        given_name: "Albert",
        family_name: "Tweedle",
        nhs_number: "9999075320",
        date_of_birth: Date.new(2009, 12, 29),
        gender_code: :male,
        address_line_1: "38A Battersea Rise",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW11 1EH",
        school: nil,
        session: @session
      )

    # Betty - will match exactly except NHS number (no review needed)
    @existing_patient_uploaded_without_nhs_number =
      create(
        :patient,
        given_name: "Betty",
        family_name: "Samson",
        nhs_number: nil,
        date_of_birth: Date.new(2010, 1, 1),
        gender_code: :female,
        address_line_1: "123 High Street",
        address_line_2: "",
        address_town: "London",
        address_postcode: "SW1A 1AA",
        school: nil,
        session: @session
      )

    @different_school = create(:gias_school, urn: "456789", team: @team)
    @different_school_session =
      create(
        :session,
        team: @team,
        location: @different_school,
        programmes: [@programme]
      )

    # Catherine - will have different address and school, causing review, and school move
    @existing_patient_duplicate_review =
      create(
        :patient,
        given_name: "Catherine",
        family_name: "Williams",
        nhs_number: "9876543210",
        date_of_birth: Date.new(2010, 5, 15),
        gender_code: :female,
        address_line_1: "999 Old Street", # Different from CSV
        address_line_2: "",
        address_town: "Birmingham", # Different from CSV
        address_postcode: "B1 1AA", # Different from CSV
        school: @different_school,
        session: @different_school_session
      )

    @existing_parent =
      create(
        :parent,
        full_name: "John Tweedle",
        email: "john.tweedle@email.com"
      )
    create(
      :parent_relationship,
      parent: @existing_parent,
      patient: @existing_patient_uploaded_with_nhs_number,
      type: "unknown"
    )

    create(:parent, full_name: "David Williams", email: "david.w@email.com")

    @existing_exact_match =
      create(
        :patient,
        given_name: "Lara",
        family_name: "Williams",
        nhs_number: "9435714463",
        date_of_birth: Date.new(2010, 5, 15),
        gender_code: :female,
        address_line_1: "",
        address_line_2: "",
        address_town: "",
        address_postcode: "B1 1AA",
        school: @school,
        session: @session
      )

    @existing_patient_duplicate_review_on_demographics =
      create(
        :patient,
        given_name: "Maia",
        family_name: "Smith",
        nhs_number: nil,
        date_of_birth: Date.new(2010, 8, 15), # Different from CSV
        gender_code: :female,
        address_line_1: "999 Old Street", # Different from CSV
        address_line_2: "",
        address_town: "Birmingham", # Different from CSV
        address_postcode: "W2 3PE",
        school: nil,
        session: @session
      )

    @existing_patient_aged_out =
      create(
        :patient,
        given_name: "Lea",
        family_name: "Smith",
        nhs_number: "9435802508",
        date_of_birth: Date.new(2008, 6, 15),
        gender_code: :female,
        address_line_1: "992 Old Street",
        address_line_2: "",
        address_town: "Birmingham",
        address_postcode: "W2 3XE",
        school: @school,
        birth_academic_year: 2008,
        session: @session
      )

    @existing_patient_deduplication_check =
      create(
        :patient,
        given_name: "Caroline",
        family_name: "Richard",
        nhs_number: nil,
        date_of_birth: Date.new(2010, 5, 15),
        gender_code: :not_known,
        address_line_1: nil,
        address_line_2: nil,
        address_town: nil,
        address_postcode: "B1 1AA",
        school: @school,
        birth_academic_year: 2012,
        session: @session
      )

    expect(Patient.count).to eq(7)
    expect(ParentRelationship.count).to eq(1)
    expect(Parent.count).to eq(2)
  end

  def and_pds_lookups_dont_return_any_matches
    Flipper.enable(:pds_search_during_import)

    csv =
      CSV.new(
        file_fixture("cohort_import/pds_extravaganza.csv").read,
        headers: true,
        header_converters: :symbol
      )

    csv.each do |row|
      family_name = row[:child_last_name]
      given_name = row[:child_first_name]
      birthdate = row[:child_date_of_birth]
      postcode = row[:child_postcode]

      next if [family_name, given_name, birthdate].any?(&:blank?)

      stub_pds_cascading_search(
        family_name: family_name,
        given_name: given_name,
        birthdate: "eq#{birthdate}",
        address_postcode: postcode
      )
    end
  end

  def and_pds_lookup_during_import_is_enabled
    Flipper.enable(:pds_search_during_import)

    stub_pds_cascading_search(
      family_name: "Tweedle",
      given_name: "Albert",
      birthdate: "eq2009-12-29",
      address_postcode: "SW11 1EH",
      steps: {
        wildcard_family_name: "9999075320"
      }
    )

    stub_pds_search_to_return_a_patient(
      "9449306168",
      "family" => "Samson",
      "given" => "Betty",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9876543210",
      "family" => "Williams",
      "given" => "Catherine",
      "birthdate" => "eq2009-05-15",
      "address-postalcode" => "SW2 2BB"
    )

    stub_pds_search_to_return_a_patient(
      "4491459835",
      "family" => "Brown",
      "given" => "Charlie",
      "birthdate" => "eq2011-03-15",
      "address-postalcode" => "SW2 2BB"
    )

    stub_pds_search_to_return_a_patient(
      "9435783309",
      "family" => "Homeschool",
      "given" => "Emma",
      "birthdate" => "eq2010-06-01",
      "address-postalcode" => "SW3 3AA"
    )

    stub_pds_search_to_return_a_patient(
      "9435714463",
      "family" => "Williams",
      "given" => "Lara",
      "birthdate" => "eq2010-05-15",
      "address-postalcode" => "B1 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9435753868",
      "family" => "Green",
      "given" => "Oliver",
      "birthdate" => "eq2010-08-15",
      "address-postalcode" => "SW1W 8JL"
    )

    stub_pds_search_to_return_a_patient(
      "9435792170",
      "family" => "McCarthy",
      "given" => "Lucy",
      "birthdate" => "eq2010-08-16",
      "address-postalcode" => "SW7 5LE"
    )

    stub_pds_cascading_search(
      family_name: "Smith",
      given_name: "Maia",
      birthdate: "eq2010-08-16",
      address_postcode: "W2 3PE"
    )

    stub_pds_cascading_search(
      family_name: "Richard",
      given_name: "Caroline",
      birthdate: "eq2010-05-15",
      address_postcode: "B1 1AA",
      steps: {
        wildcard_postcode: "1111111111",
        wildcard_family_name: "9435726097"
      }
    )
  end

  def stub_pds_cascading_search(
    family_name:,
    given_name:,
    birthdate:,
    address_postcode:,
    steps: {}
  )
    stub_pds_search_to_return_no_patients(
      "family" => family_name,
      "given" => given_name,
      "birthdate" => birthdate,
      "address-postalcode" => address_postcode
    )

    {
      wildcard_postcode: {
        "family" => family_name,
        "given" => given_name,
        "birthdate" => birthdate,
        "address-postalcode" => "#{address_postcode[0..1]}*"
      },
      wildcard_given_name: {
        "family" => family_name,
        "given" => "#{given_name[0..2]}*",
        "birthdate" => birthdate,
        "address-postalcode" => address_postcode
      },
      wildcard_family_name: {
        "family" => "#{family_name[0..2]}*",
        "given" => given_name,
        "birthdate" => birthdate,
        "address-postalcode" => address_postcode
      }
    }.each do |step, query|
      if steps[step]
        stub_pds_search_to_return_a_patient(steps[step], **query)
      else
        stub_pds_search_to_return_no_patients(**query)
      end
    end
  end

  def when_i_visit_the_import_page
    visit "/"
    click_link "Import", match: :first
  end

  def when_i_go_back_to_the_import_page
    visit "/imports"
    click_link "1 September 2025 at 12:00pm"
  end

  def when_i_click_on_alberts_pds_history
    find(".nhsuk-details__summary", text: "10 imported records").click
    click_on "TWEEDLE, Albert"
    click_link "PDS history"
  end

  def when_i_click_review_for(name)
    within(:xpath, "//div[h3[contains(text(), 'Close matches')]]") do
      within(:xpath, ".//tr[contains(., '#{name}')]") { click_link "Review" }
    end
  end

  def and_i_upload_import_file(filename)
    travel 1.minute

    click_button "Upload records"
    choose "Child records"
    click_button "Continue"
    attach_file_fixture "cohort_import[csv]", "cohort_import/#{filename}"
    click_on "Continue"

    wait_for_import_to_complete(CohortImport)
  end

  def when_i_visit_a_school_for_the_hpv_programme
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Waterloo Road"
  end

  def then_i_should_see_the_import_failed
    expect(page).to have_content("Too many records could not be matched")
    expect(page).to have_content("12 unmatched records")
  end

  def then_i_should_see_the_import_is_invalid
    expect(page).to have_content("Upload failed")
    expect(page).to have_content(
      "This may include errors identified after Mavis added a missing NHS number or replaced an incorrect NHS number."
    )
    expect(page).to have_content(
      "The details on this row match row 5. Mavis has found the NHS number 9876543210."
    )
    expect(page).to have_content(
      "The record on this row appears to be a duplicate of row 5."
    )
  end

  def then_i_see_the_pds_lookup_history
    expect(page).to have_content("NHS number lookup history")
  end

  def when_i_upload_a_valid_file
    attach_file_fixture "class_import[csv]", "class_import/pds_extravaganza.csv"
    click_on "Continue"
    wait_for_import_to_complete(ClassImport)
  end

  def when_i_visit_the_import_page
    visit "/"
    click_link "Import", match: :first
  end

  def when_i_go_back_to_the_import_page
    visit "/imports/records"

    click_on_most_recent_import(CohortImport)
  end

  def when_i_click_review_for(name)
    within(
      :xpath,
      "//h2[contains(text(), 'Close matches')]/following-sibling::details[1]"
    ) do
      within(:xpath, ".//tr[contains(., '#{name}')]") { click_link "Review" }
    end
  end

  def and_i_start_adding_children_to_the_school
    click_on "Import class lists"
  end

  def and_i_select_the_year_groups
    check "Year 8"
    check "Year 9"
    check "Year 10"
    click_on "Continue"
  end

  def and_an_existing_patient_records_exist_in_school
    @existing_patient =
      create(
        :patient,
        given_name: "Albert",
        family_name: "Tweedle",
        nhs_number: "9999075320",
        date_of_birth: Date.new(2009, 12, 29),
        gender_code: :male,
        address_line_1: "38A Battersea Rise",
        address_line_2: nil,
        address_town: "London",
        address_postcode: "SW11 1EH",
        school: @school,
        registration: nil,
        session: @session
      )

    @existing_patient_moved_out =
      create(
        :patient,
        given_name: "John",
        family_name: "Smith",
        nhs_number: "9435783309",
        date_of_birth: Date.new(2009, 10, 29),
        gender_code: :male,
        address_line_1: "39A Battersea Rise",
        address_line_2: nil,
        address_town: "London",
        address_postcode: "SW1 1AA",
        school: @school,
        registration: nil,
        session: @session
      )
  end

  def then_i_do_not_see_an_import_review_for_the_first_patient_uploaded_without_nhs_number
    find(".nhsuk-details__summary", text: "2 upload issues").click
    expect(page).not_to have_content("ActionsReview SAMSON, Betty")
  end

  def when_i_click_on_the_patient_without_review
    find(".nhsuk-details__summary", text: "10 imported records").click
    click_link "SAMSON, Betty"
  end

  def then_i_see_an_import_review_for_the_second_patient_uploaded_without_nhs_number
    find(".nhsuk-details__summary", text: "2 upload issues").click
    expect(page).to have_content("Matched on NHS number.")
  end

  def when_i_click_on_new_patient_uploaded_without_an_nhs_number
    find(".nhsuk-details__summary", text: "10 imported records").click
    click_link "BROWN, Charlie"
  end

  def when_i_use_duplicate_record_during_merge
    choose "Use uploaded child record"
    click_on "Resolve duplicate"
  end

  def then_i_should_see_the_import_page
    expect(page).to have_content("Uploaded byUSER, Test")
  end

  def and_i_should_see_one_new_patient_created
    perform_enqueued_jobs
    expect(Patient.count).to eq(7)
  end

  def and_i_see_the_patient_uploaded_with_nhs_number
    expect(page).to have_content(
      "Name and NHS number TWEEDLE, Albert 999 907 5320"
    )
  end

  def then_i_see_the_new_patient_has_an_nhs_number
    expect(page).to have_content("944 930 6168")
    expect(page).to have_content("SAMSON, Betty")
    expect(page).to have_content("1 January 2010 (aged 15)")
  end

  def then_i_see_both_records_have_an_nhs_number
    expect(page).to have_text("987 654 3210", count: 2)
  end

  def then_i_see_the_new_patient_now_has_an_nhs_number
    expect(page).to have_content("NHS number449 145 9835")
    expect(page).to have_content("Full nameBROWN, Charlie")
    expect(page).to have_content("Date of birth15 March 2011 (aged 14)")
  end

  def then_the_existing_patient_has_an_nhs_number_in_mavis
    expect(Patient.count).to eq(11)
    patient = Patient.where(given_name: "Catherine").first
    expect(patient.nhs_number).to eq("9876543210")
    expect(patient.address_line_1).to eq("456 New Street")
    expect(patient.address_town).to eq("London")
    expect(patient.address_postcode).to eq("SW2 2BB")
  end

  def and_i_should_see_correct_patient_counts
    expect(Patient.count).to eq(11)
  end

  def and_parents_are_created_for_albert
    albert = Patient.find_by(given_name: "Albert", family_name: "Tweedle")
    expect(albert.parents.count).to eq(2)
    expect(albert.parents.map(&:full_name)).to contain_exactly(
      "John Tweedle",
      "Mary Tweedle"
    )
    expect(albert.parents.find_by(full_name: "John Tweedle").email).to eq(
      "john.tweedle@email.com"
    )
  end

  def and_betty_has_correct_parent_relationships
    betty = Patient.find_by(given_name: "Betty", family_name: "Samson")
    expect(betty.parent_relationships.count).to eq(2)

    dad_relationship =
      betty
        .parent_relationships
        .joins(:parent)
        .find_by(parents: { full_name: "Robert Samson" })
    expect(dad_relationship.type).to eq("father")

    mum_relationship =
      betty
        .parent_relationships
        .joins(:parent)
        .find_by(parents: { full_name: "Linda Samson" })
    expect(mum_relationship.type).to eq("mother")

    linda = Parent.find_by(full_name: "Linda Samson")
    expect(linda.phone).to be_blank
    expect(linda.phone_receive_updates).to be false
  end

  def and_i_see_address_differences_for_review
    expect(page).to have_content("999 Old Street") # Original address
    expect(page).to have_content("456 New Street") # New address from CSV
    expect(page).to have_content("Birmingham") # Original town
    expect(page).to have_content("London") # New town from CSV
  end

  def and_i_do_not_see_the_option_to_keep_both
    expect(page).not_to have_content("Keep both child records")
  end

  def and_catherine_parents_are_handled_correctly
    catherine =
      Patient.find_by(given_name: "Catherine", family_name: "Williams")
    expect(catherine.parents.count).to eq(1)

    guardian = catherine.parents.find_by(full_name: "David Williams")
    guardian_relationship =
      catherine.parent_relationships.find_by(parent: guardian)
    expect(guardian_relationship.type).to eq("guardian")
  end

  def and_charlie_has_no_parents_as_expected
    charlie = Patient.find_by(given_name: "Charlie", family_name: "Brown")
    expect(charlie.parents.count).to eq(0)
    expect(charlie.parent_relationships.count).to eq(0)
  end

  def when_i_click_on_home_educated_patient
    find(".nhsuk-details__summary", text: "10 imported records").click
    click_link "HOMESCHOOL, Emma"
  end

  def then_i_see_home_educated_patient_details
    expect(page).to have_content("HOMESCHOOL, Emma")
    expect(page).to have_content("1 June 2010")
  end

  def and_emma_has_correct_parent_data
    emma = Patient.find_by(given_name: "Emma", family_name: "Homeschool")
    expect(emma.parents.count).to eq(1)

    father = emma.parents.first
    expect(father.full_name).to eq("Mike HomeDad")
    expect(father.email).to eq("mike@home.com")

    relationship = emma.parent_relationships.first
    expect(relationship.type).to eq("father")
  end

  def then_school_moves_are_created_appropriately
    perform_enqueued_jobs
    perform_enqueued_jobs

    Sidekiq::Job.drain_all # PatientsAgedOutOfSchoolJob is Sidekiq-only

    charlie = Patient.find_by(given_name: "Charlie")
    charlie_move = SchoolMoveLogEntry.find_by(patient: charlie)
    expect(charlie_move).to be_present
    expect(charlie_move.school).to eq(@school)

    emma = Patient.find_by(given_name: "Emma")
    emma_move = SchoolMoveLogEntry.find_by(patient: emma)
    expect(emma_move).to be_present
    expect(emma_move.school).to eq(@team.home_educated_school)

    catherine =
      Patient.find_by(given_name: "Catherine", family_name: "Williams")
    catherine_move = SchoolMove.find_by(patient: catherine, school: @school)
    expect(catherine_move).to be_present
    catherine_log_entry = SchoolMoveLogEntry.find_by(patient: catherine)
    expect(catherine_log_entry).to be_nil
    expect(catherine.school).to eq(@different_school)

    lea = Patient.find_by(given_name: "Lea", family_name: "Smith")
    lea_move = SchoolMoveLogEntry.find_by(patient: lea)
    expect(lea_move.school).to eq(@team.unknown_school)
  end

  def and_all_parent_relationships_are_established
    expect(Parent.count).to eq(7)
    expect(ParentRelationship.count).to eq(7)

    father_relationships = ParentRelationship.where(type: "father")
    expect(father_relationships.count).to eq(3) # John Tweedle, Mike HomeDad, Robert Samson

    mother_relationships = ParentRelationship.where(type: "mother")
    expect(mother_relationships.count).to eq(2) # Mary Tweedle, Linda Samson

    guardian_relationships = ParentRelationship.where(type: "guardian")
    expect(guardian_relationships.count).to eq(1) # David Williams

    unknown_relationships = ParentRelationship.where(type: "unknown")
    expect(unknown_relationships.count).to eq(1) # Jane Doe
  end

  def and_import_counts_are_correct
    import = CohortImport.last
    expect(import.patients.count).to eq(10)
  end

  def when_i_click_on_patient_with_unknown_relationship
    find(".nhsuk-details__summary", text: "10 imported records").click
    click_link "GREEN, Oliver"
  end

  def then_i_see_patient_with_unknown_relationship_details
    expect(page).to have_content("GREEN, Oliver")
    expect(page).to have_content("15 August 2010")
  end

  def and_oliver_has_unknown_relationship_parent
    oliver = Patient.find_by(given_name: "Oliver", family_name: "Green")
    expect(oliver.parents.count).to eq(1)

    parent = oliver.parents.first
    expect(parent.full_name).to eq("Jane Doe")
    expect(parent.email).to be_blank

    relationship = oliver.parent_relationships.first
    expect(relationship.type).to eq("unknown")
    expect(relationship.label).to eq("Unknown")
  end

  def and_i_should_see_no_duplicate_reviews
    expect(page).not_to have_content("upload issues")
  end

  def and_the_registration_on_albert_should_be_set
    albert = Patient.find_by(given_name: "Albert", family_name: "Tweedle")
    expect(albert.registration).to eq("Kangaroos")
  end

  def and_school_move_created_for_patient_not_in_import
    expect(SchoolMove.count).to eq(1)
    expect(SchoolMove.first.patient).to eq(
      Patient.find_by(given_name: "John", family_name: "Smith")
    )
  end

  def then_i_see_one_record_is_an_exact_match
    expect(CohortImport.processed.sole.exact_duplicate_record_count).to eq(2)
  end

  def then_i_see_an_nhs_discrepancy
    expect(page).to have_content("1 NHS number updated")
  end

  def and_lucy_has_the_pds_nhs_number
    lucy = Patient.find_by(given_name: "Lucy", family_name: "McCarthy")
    expect(lucy.nhs_number).to eq("9435792170")
  end

  def and_there_is_an_import_review_for_maia
    find(".nhsuk-details__summary", text: "1 upload issue").click
    expect(page).to have_content("Actions Review SMITH, Maia")
    expect(page).to have_content("Possible match found. Review and confirm.")
  end

  def when_i_review_and_accept_duplicate_maia_record
    click_link "Review"
    expect(page).to have_content("Keep both child records")
    choose "Use uploaded child record"
    click_on "Resolve duplicate"
  end

  def then_maia_has_the_uploaded_nhs_number
    maia = Patient.find_by(given_name: "Maia", family_name: "Smith")
    expect(maia.nhs_number).to eq("9435789102")
  end

  def and_maia_has_multiple_pds_search_results
    maia = Patient.find_by(given_name: "Maia", family_name: "Smith")
    expect(maia.pds_search_results.count).to eq(4)
    expect(maia.pds_search_results.pluck(:step)).to eq(
      %w[
        no_fuzzy_with_history
        no_fuzzy_with_wildcard_postcode
        no_fuzzy_with_wildcard_given_name
        no_fuzzy_with_wildcard_family_name
      ]
    )
  end
end
