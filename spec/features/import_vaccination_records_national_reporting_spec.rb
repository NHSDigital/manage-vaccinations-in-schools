# frozen_string_literal: true

describe("National reporting immunisation imports") do
  context "at a specified date" do
    around { |example| travel_to(Date.new(2025, 12, 20)) { example.run } }

    scenario "User uploads a mixed flu and HPV file, views cohort and vaccination records" do
      given_mavis_logins_are_configured
      given_i_am_signed_in_as_a_national_reporting_user
      given_a_patient_already_exists
      and_sending_to_nhs_immunisations_api_is_enabled

      when_i_go_to_the_import_page
      then_i_should_see_the_upload_link
      and_i_should_not_see_any_reference_to_import_issues

      when_i_click_on_the_upload_link
      then_i_should_see_the_upload_page

      when_i_continue_without_uploading_a_file
      then_i_should_see_an_error

      when_i_upload_an_invalid_file
      then_i_should_see_the_errors_page

      travel_to 1.minute.from_now # to ensure the created_at is different for the import jobs

      when_i_go_back_to_the_upload_page
      and_i_upload_a_valid_mixed_file
      then_i_should_see_the_upload
      and_i_should_see_some_stats_about_the_import
      and_i_should_see_the_vaccination_records
      and_the_patients_should_now_be_associated_with_the_team
      and_the_newly_created_patients_should_be_archived
      and_the_existing_patients_should_not_be_archived
      and_the_vaccination_records_are_sent_to_the_imms_api

      when_i_click_on_a_vaccination_record
      then_i_should_see_the_vaccination_record

      when_i_go_to_the_children_page
      and_i_search_for_existing_patient
      then_i_should_see_the_existing_patient
      when_i_search_for_new_patient
      then_i_should_see_the_new_patient

      travel_to 1.minute.from_now

      when_i_navigate_to_the_upload_page
      and_i_upload_a_valid_mixed_file # The exact same file again
      then_i_should_see_the_upload
      and_no_new_vaccination_records_were_created
    end
  end

  context "cutoff date banner" do
    let(:cutoff_date) { Date.new(2026, 4, 20) }

    context "when today is more than 2 days after the cutoff date" do
      around { |example| travel_to(cutoff_date + 3.days) { example.run } }

      scenario "banner is not shown" do
        given_mavis_logins_are_configured(
          national_reporting_cut_off_date: cutoff_date
        )
        given_i_am_signed_in_as_a_national_reporting_user
        when_i_navigate_to_the_upload_page
        expect(page).not_to have_css(".nhsuk-notification-banner")
      end
    end

    context "when today is within 2 days after the cutoff date" do
      around { |example| travel_to(cutoff_date + 2.days) { example.run } }

      scenario "banner is shown" do
        given_mavis_logins_are_configured(
          national_reporting_cut_off_date: cutoff_date
        )
        given_i_am_signed_in_as_a_national_reporting_user
        when_i_navigate_to_the_upload_page
        expect(page).to have_css(".nhsuk-notification-banner")
        expect(page).to have_content(
          "Mavis national reporting replaces NIVS on 20 April 2026"
        )
      end
    end

    context "when today is before the cutoff date" do
      around { |example| travel_to(cutoff_date - 1.day) { example.run } }

      scenario "banner is shown" do
        given_mavis_logins_are_configured(
          national_reporting_cut_off_date: cutoff_date
        )
        given_i_am_signed_in_as_a_national_reporting_user
        when_i_navigate_to_the_upload_page
        expect(page).to have_css(".nhsuk-notification-banner")
        expect(page).to have_content(
          "Mavis national reporting replaces NIVS on 20 April 2026"
        )
      end
    end

    context "when today is the cutoff date" do
      around { |example| travel_to(cutoff_date) { example.run } }

      scenario "banner is shown" do
        given_mavis_logins_are_configured(
          national_reporting_cut_off_date: cutoff_date
        )
        given_i_am_signed_in_as_a_national_reporting_user
        when_i_navigate_to_the_upload_page
        expect(page).to have_css(".nhsuk-notification-banner")
        expect(page).to have_content(
          "Mavis national reporting replaces NIVS on 20 April 2026"
        )
        expect(page).to have_content("Vaccinations given before 20 April 2026")
        expect(page).to have_content(
          "Upload to NIVS by 22 April 2026. After this, NIVS will no longer be available."
        )
        expect(page).to have_content(
          "Vaccinations given on or after 20 April 2026"
        )
        expect(page).to have_content("Upload to Mavis national reporting only.")
      end
    end
  end

  def given_mavis_logins_are_configured(national_reporting_cut_off_date: nil)
    @team =
      create(
        :team,
        :national_reporting,
        :with_one_nurse,
        ods_code: "R1L",
        national_reporting_cut_off_date:
      )
    @school = create(:gias_school, team: @team, urn: 100_000)
  end

  def given_i_am_signed_in_as_a_national_reporting_user
    @user = @team.users.first
    sign_in @user
  end

  def given_a_patient_already_exists
    @existing_patient =
      create(
        :patient,
        given_name: "Harry",
        family_name: "Potter",
        date_of_birth: Date.new(2001, 1, 1),
        nhs_number: "9449308357",
        team: @team
      )

    # Create a vaccination record to link this patient with the team
    create(
      :vaccination_record,
      patient: @existing_patient,
      team: @team,
      session: create(:session, team: @team, location: @school)
    )
  end

  def and_sending_to_nhs_immunisations_api_is_enabled
    Flipper.enable(:imms_api_integration)
    Flipper.enable(:imms_api_sync_job, Programme.flu)
    Flipper.enable(:imms_api_sync_job, Programme.hpv)
    Flipper.enable(:sync_national_reporting_to_imms_api)

    @stubbed_post_request =
      stub_immunisations_api_post(Random.uuid, Random.uuid)
  end

  def when_i_go_to_the_import_page
    visit "/dashboard"

    click_on "Import", match: :first
  end

  def then_i_should_see_the_upload_link
    expect(page).to have_button("Upload records")
  end

  def and_i_should_not_see_any_reference_to_import_issues
    expect(page).not_to have_content(
      "Any close matches to resolve will appear in the Issues tab."
    )

    navigation_items = page.all(".app-secondary-navigation__link")
    expect(navigation_items.map(&:text)).not_to include(
      a_string_including("Issues")
    )
  end

  def when_i_click_on_the_upload_link
    click_on "Upload records"
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
                        "immunisation_import/national_reporting/invalid_rows.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def then_i_should_see_the_errors_page
    expect(page).to have_content("What your CSV file must include")
    expect(page).to have_content("Row 2")
    expect(page).to have_content("ANATOMICAL_SITE:")
    expect(page).to have_content("SCHOOL_URN:")

    expect(page).to have_content("Row 3")
    expect(page).to have_content("BATCH_EXPIRY_DATE:")
  end

  def when_i_go_back_to_the_upload_page
    click_on "Back"
    click_on "Upload records"
  end

  def when_i_navigate_to_the_upload_page
    visit "/immunisation-imports/new"
  end

  def and_i_upload_a_valid_mixed_file
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/national_reporting/valid_mixed_flu_hpv.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def and_i_should_see_the_vaccination_records
    expect(page).to have_content(
      "Full nameNHS numberDate of birthVaccination date"
    )
    expect(page).to have_content("Full name POTTER, Harry")
    expect(page).to have_content(/NHS number.*944.*930.*8357/)
    expect(page).to have_content("Date of birth 1 January 2001")
    expect(page).to have_content("Vaccination date 9 November 2025")
  end

  def then_i_should_see_the_upload
    expect(page).to have_content("Uploaded byUSER, Test")
  end

  def and_i_should_see_some_stats_about_the_import
    expect(page).to have_content("3 records found in the file:")
    expect(page).to have_content("2 new records imported")
    expect(page).to have_content("0 duplicates not imported")
    expect(page).to have_content("1 ‘not vaccinated’ record not imported")
  end

  def and_the_patients_should_now_be_associated_with_the_team
    Patient.all.find_each { |patient| expect(patient.teams).to include(@team) }
  end

  def and_the_newly_created_patients_should_be_archived
    new_patient = Patient.find_by(nhs_number: "9999075320")
    expect(new_patient.archived?(team: @team)).to be true
    expect(new_patient.archive_reasons.first.type).to eq "immunisation_import"
  end

  def and_the_existing_patients_should_not_be_archived
    expect(@existing_patient.archived?(team: @team)).to be false
  end

  def and_the_vaccination_records_are_sent_to_the_imms_api
    SyncVaccinationRecordToNHSJob.drain

    expect(@stubbed_post_request).to have_been_requested.times(2)
  end

  def when_i_click_on_a_vaccination_record
    find(".nhsuk-details__summary", text: "2 imported records").click
    click_on "WEASLEY, Ron"
  end

  def then_i_should_see_the_vaccination_record
    expect(page).to have_content("WEASLEY, Ron")
    expect(page).to have_content("Child")
    expect(page).to have_content("Full nameWEASLEY, Ron")
    expect(page).to have_content("Vaccination details")
    expect(page).to have_content("OutcomeVaccinated")
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
    @new_patient = Patient.find_by(nhs_number: "9999075320")
    fill_in "Search", with: @new_patient.full_name
    click_button "Search"
  end

  def then_i_should_see_the_new_patient
    expect(page).to have_content(@new_patient.full_name)
  end

  def and_no_new_vaccination_records_were_created
    expect(VaccinationRecord.count).to eq(3)
  end
end
