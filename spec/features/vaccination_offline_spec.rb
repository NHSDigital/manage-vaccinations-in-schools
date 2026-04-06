# frozen_string_literal: true

describe "Offline vaccination" do
  around do |example|
    travel_to(Time.zone.local(2024, 2, 1, 12)) { example.run }
  end

  scenario "Download spreadsheet, record offline at a school session, upload vaccination outcomes back into Mavis" do
    stub_pds_get_nhs_number_to_return_a_patient

    given_an_hpv_programme_is_underway
    when_i_choose_to_record_offline_from_a_school_session_page
    then_i_see_an_excel_spreadsheet_for_recording_offline

    when_i_record_vaccination_outcomes_to_the_spreadsheet_and_export_it_to_csv
    and_i_upload_the_modified_csv_file
    then_i_see_the_successful_import
    when_i_navigate_to_the_session_page
    then_i_see_the_uploaded_vaccination_outcomes_reflected_in_the_session

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Download spreadsheet, record offline at a clinic, upload vaccination outcomes back into Mavis" do
    stub_pds_get_nhs_number_to_return_a_patient

    given_an_hpv_programme_is_underway(clinic: true)
    when_i_choose_to_record_offline_from_a_school_page
    then_i_see_an_excel_spreadsheet_for_recording_offline

    when_i_record_vaccination_outcomes_to_the_spreadsheet_and_export_it_to_csv
    and_i_upload_the_modified_csv_file
    then_i_see_the_successful_import
    when_i_navigate_to_the_clinic_page
    then_i_see_the_uploaded_vaccination_outcomes_reflected_in_the_session
    and_the_clinic_location_is_displayed

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "User uploads duplicates in an offline recording for a session" do
    given_an_hpv_programme_is_underway_with_a_single_patient
    and_imms_api_sync_job_feature_is_enabled

    when_i_choose_to_record_offline_from_a_school_session_page
    and_alter_an_existing_vaccination_record_to_create_a_duplicate
    and_i_upload_the_modified_csv_file
    then_i_see_a_duplicate_record_needs_review

    when_i_review_the_duplicate_record
    then_i_should_see_the_changes
    and_i_shouldnt_see_the_synced_with_nhs_row

    when_i_choose_to_keep_the_duplicate_record
    then_i_should_see_a_success_message
    and_the_vaccination_record_is_synced_to_nhs

    when_i_change_the_vaccination_outcome_to_not_vaccinated
    and_i_upload_the_modified_csv_file
    and_i_review_the_duplicate_record
    and_i_choose_to_keep_the_duplicate_record
    then_i_should_see_a_success_message
    and_the_vaccination_record_is_deleted_from_nhs
  end

  scenario "User tries to edit vaccination record sourced from NHS immunisations API in offline workflow" do
    given_a_flu_programme_is_underway_with_a_single_patient
    and_the_patients_record_is_sourced_from_nhs_api

    when_i_choose_to_record_offline_from_a_school_session_page
    and_alter_an_existing_vaccination_record_to_create_a_duplicate
    and_i_upload_the_modified_csv_file
    then_i_see_a_duplicate_record_needs_review

    when_i_review_the_duplicate_record
    then_i_should_see_the_nhs_api_restriction_message
    and_i_should_only_see_discard_option
    and_i_should_not_see_radio_buttons

    when_i_discard_the_incoming_changes
    then_i_should_see_a_success_message
    and_the_nhs_api_record_should_remain_unchanged

    when_i_go_to_the_import_page
    then_i_should_see_no_import_issues_with_the_count
  end

  scenario "User can upload un-edited vaccination records sourced from NHS immunisations API in offline workflow" do
    given_a_flu_programme_is_underway_with_a_single_patient
    and_the_patients_record_is_sourced_from_nhs_api

    when_i_choose_to_record_offline_from_a_school_session_page
    and_i_save_the_csv_file
    and_i_upload_the_modified_csv_file
    then_i_see_that_no_records_need_review
    and_the_nhs_api_record_should_remain_unchanged

    when_i_go_to_the_import_page
    then_i_should_see_no_import_issues_with_the_count
  end

  def given_an_hpv_programme_is_underway(clinic: false)
    programmes = [Programme.hpv]

    @team = create(:team, :with_one_nurse, programmes:)
    school = clinic ? @team.unknown_school : create(:school, team: @team)
    previous_date = 1.month.ago.to_date

    if clinic
      @generic_clinic_session =
        create(
          :session,
          team: @team,
          programmes:,
          location: @team.generic_clinic,
          dates: [previous_date, Date.current]
        )

      @community_clinic =
        create(
          :community_clinic,
          name: "Westfield Shopping Centre",
          team: @team
        )
    end

    vaccine = programmes.first.vaccines.active.first
    @batch = create(:batch, :not_expired, team: @team, vaccine:)

    create(:gp_practice, ods_code: "Y12345")

    unless clinic
      @session =
        create(
          :session,
          :today,
          team: @team,
          programmes:,
          location: school,
          dates: [previous_date, Date.current]
        )
    end

    @vaccinated_patient, @unvaccinated_patient =
      create_list(
        :patient,
        2,
        :consent_given_triage_not_needed,
        school:,
        session: clinic ? @generic_clinic_session : @session,
        year_group: 8
      )
    @previously_vaccinated_patient =
      create(
        :patient,
        :vaccinated,
        school:,
        session: clinic ? @generic_clinic_session : @session,
        location_name: clinic ? @community_clinic.name : nil,
        year_group: 8
      )

    VaccinationRecord.last.update!(
      performed_at: previous_date,
      performed_by: @team.users.first,
      notify_parents: true
    )

    @restricted_vaccinated_patient =
      create(
        :patient,
        :vaccinated,
        :restricted,
        school:,
        session: clinic ? @generic_clinic_session : @session,
        location_name: clinic ? @community_clinic.name : nil,
        year_group: 8
      )

    PatientStatusUpdater.call
  end

  def given_an_hpv_programme_is_underway_with_a_single_patient
    programmes = [Programme.hpv]

    @team = create(:team, :with_one_nurse, programmes:)
    school = create(:school, team: @team)
    previous_date = 1.month.ago.to_date

    vaccine = programmes.first.vaccines.active.first
    @batch = create(:batch, :not_expired, team: @team, vaccine:)

    @session =
      create(
        :session,
        :today,
        team: @team,
        programmes:,
        location: school,
        dates: [previous_date, Date.current]
      )

    @previously_vaccinated_patient =
      create(:patient, :vaccinated, session: @session, school:, year_group: 8)

    VaccinationRecord.last.update!(
      performed_at: previous_date,
      performed_by: @team.users.first,
      notify_parents: true
    )

    PatientStatusUpdater.call
  end

  def given_a_flu_programme_is_underway_with_a_single_patient
    programmes = [Programme.flu]

    @team = create(:team, :with_one_nurse, programmes:, ods_code: "B0C4P")
    school = create(:school, team: @team)

    vaccine = programmes.first.vaccines.active.first
    @batch = create(:batch, :not_expired, team: @team, vaccine:)

    @session =
      create(
        :session,
        :today,
        team: @team,
        programmes:,
        location: school,
        dates: [1.month.ago.to_date, Date.current]
      )

    @previously_vaccinated_patient =
      create(:patient, session: @session, school:, year_group: 8)
  end

  def and_the_patients_record_is_sourced_from_nhs_api
    fhir_record =
      FHIR.from_contents(file_fixture("fhir/flu/fhir_record_full.json").read)
    @nhs_api_vaccination_record =
      FHIRMapper::VaccinationRecord.from_fhir_record(
        fhir_record,
        patient: @previously_vaccinated_patient
      )
    @nhs_api_vaccination_record.performed_at = 1.month.ago
    @nhs_api_vaccination_record.notes = "Imported from NHS API"
    @nhs_api_vaccination_record.save!
  end

  def and_imms_api_sync_job_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, Programme.hpv)
    Flipper.enable(:imms_api_integration)

    immunisation_uuid = Random.uuid
    @stubbed_post_request = stub_immunisations_api_post(uuid: immunisation_uuid)
    @stubbed_put_request = stub_immunisations_api_put(uuid: immunisation_uuid)
    @stubbed_delete_request =
      stub_immunisations_api_delete(uuid: immunisation_uuid)
  end

  def and_i_upload_a_file_with_duplicate_nhs_api_records
    visit "/"
    click_on "Import", match: :first
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"

    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/valid_hpv_offline_spreadsheet.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
  end

  def when_i_review_the_nhs_api_duplicate_record
    click_link "Review"
  end

  def then_i_should_see_the_nhs_api_restriction_message
    expect(page).to have_content("You cannot keep the incoming changes")
    expect(page).to have_content(
      "The existing record was imported automatically from an external source, such as a GP practice, meaning that " \
        "Mavis is not the primary source for this vaccination record."
    )
  end

  def and_i_should_only_see_discard_option
    expect(page).to have_button("Discard incoming changes")
  end

  def and_i_should_not_see_radio_buttons
    expect(page).not_to have_content("Apply the uploaded changes")
    expect(page).not_to have_content("Keep the existing record")
    expect(page).not_to have_selector("input[type='radio']")
  end

  def when_i_discard_the_incoming_changes
    click_button "Discard incoming changes"
  end

  def and_the_nhs_api_record_should_remain_unchanged
    @nhs_api_vaccination_record.reload
    expect(@nhs_api_vaccination_record.notes).to eq("Imported from NHS API")
    expect(@nhs_api_vaccination_record.source).to eq("nhs_immunisations_api")
    expect(@nhs_api_vaccination_record.outcome).to eq("administered")
    expect(@nhs_api_vaccination_record.delivery_site).to eq(
      "left_arm_upper_position"
    )
  end

  def when_i_go_to_the_import_page
    click_link "Import", match: :first
  end

  def then_i_should_see_no_import_issues_with_the_count
    expect(page).to have_content("Issues (0)")
  end

  def when_i_choose_to_record_offline_from_a_school_session_page
    sign_in @team.users.first
    visit session_path(@session)
    click_on "Download offline spreadsheet"
  end

  def when_i_choose_to_record_offline_from_a_school_page
    sign_in @team.users.first
    visit "/dashboard"
    click_link "Schools", match: :first
    click_link "Unknown school"
    click_on "Download offline spreadsheet"
  end

  def and_alter_an_existing_vaccination_record_to_create_a_duplicate
    expect(page.status_code).to eq(200)

    @workbook = RubyXL::Parser.parse_buffer(page.body)
    @sheet = @workbook["Vaccinations"]
    @headers = @sheet[0].cells.map(&:value)

    array = @workbook[0].to_a[1..].map(&:cells).map { it.map(&:value) }
    csv_table =
      CSV::Table.new(
        array.map do |row|
          CSV::Row.new(@headers, row.map { |cell| excel_cell_to_csv(cell) })
        end
      )

    row_for_vaccinated_patient = csv_table[0]

    # Change details for the patient
    row_for_vaccinated_patient["NHS_NUMBER"] = ""

    # Change details for the vaccination record
    row_for_vaccinated_patient["DOSE_SEQUENCE"] = "2"
    row_for_vaccinated_patient["ANATOMICAL_SITE"] = "Right Upper Arm"

    File.write("tmp/modified.csv", csv_table.to_csv)
  end

  def and_i_save_the_csv_file
    expect(page.status_code).to eq(200)

    @workbook = RubyXL::Parser.parse_buffer(page.body)
    @sheet = @workbook["Vaccinations"]
    @headers = @sheet[0].cells.map(&:value)

    array = @workbook[0].to_a[1..].map(&:cells).map { it.map(&:value) }
    csv_table =
      CSV::Table.new(
        array.map do |row|
          CSV::Row.new(@headers, row.map { |cell| excel_cell_to_csv(cell) })
        end
      )

    File.write("tmp/modified.csv", csv_table.to_csv)
  end

  def when_i_change_the_vaccination_outcome_to_not_vaccinated
    csv_table = CSV.read("tmp/modified.csv", headers: true)

    row_for_vaccinated_patient = csv_table[0]
    row_for_vaccinated_patient["VACCINATED"] = "N"
    row_for_vaccinated_patient["REASON_NOT_VACCINATED"] = "refused"
    row_for_vaccinated_patient["BATCH_EXPIRY_DATE"] = nil
    row_for_vaccinated_patient["BATCH_NUMBER"] = nil
    row_for_vaccinated_patient["ANATOMICAL_SITE"] = nil

    File.write("tmp/modified.csv", csv_table.to_csv)
  end

  def when_i_review_the_duplicate_record
    find(".nhsuk-details__summary", text: "1 upload issue").click
    click_on "Review"
  end
  alias_method :and_i_review_the_duplicate_record,
               :when_i_review_the_duplicate_record

  def then_i_should_see_the_changes
    expect(page).to have_css(
      ".app-highlight",
      text: "Right arm (upper position)"
    )
  end

  def and_i_shouldnt_see_the_synced_with_nhs_row
    expect(page).not_to have_content("Synced with NHS England?")
  end

  def when_i_choose_to_keep_the_duplicate_record
    choose "Use uploaded vaccination record"
    click_on "Resolve duplicate"
  end
  alias_method :and_i_choose_to_keep_the_duplicate_record,
               :when_i_choose_to_keep_the_duplicate_record

  def then_i_see_an_excel_spreadsheet_for_recording_offline
    expect(page.status_code).to eq(200)

    @workbook = RubyXL::Parser.parse_buffer(page.body)
    @sheet = @workbook["Vaccinations"]
    @headers = @sheet[0].cells.map(&:value)

    expect(@headers).to include("ORGANISATION_CODE")
  end

  def excel_cell_to_csv(value)
    case value
    when Date
      value.strftime("%d/%m/%Y")
    when Time
      value.strftime("%H:%M:%S")
    else
      value
    end
  end

  def when_i_record_vaccination_outcomes_to_the_spreadsheet_and_export_it_to_csv
    # the steps below roughly approximate SAIS users:
    #
    # * opening the spreadsheet in Excel
    # * recording vaccinations into it
    # * exporting it to CSV
    #
    # ideally we could drive Excel here (or similar) but the code below is better than nothing

    array = @workbook[0].to_a[1..].map(&:cells).map { it.map(&:value) }
    csv_table =
      CSV::Table.new(
        array.map do |row|
          CSV::Row.new(@headers, row.map { |cell| excel_cell_to_csv(cell) })
        end
      )

    row_for_vaccinated_patient =
      csv_table.find do |row|
        row["PERSON_FORENAME"] == @vaccinated_patient.given_name &&
          row["PERSON_SURNAME"] == @vaccinated_patient.family_name
      end
    row_for_vaccinated_patient["DATE_OF_VACCINATION"] = Date.current.strftime(
      "%d/%m/%Y"
    )
    row_for_vaccinated_patient["TIME_OF_VACCINATION"] = "10:00:00"
    row_for_vaccinated_patient["VACCINATED"] = "Y"
    row_for_vaccinated_patient["VACCINE_GIVEN"] = "Gardasil9"
    row_for_vaccinated_patient["BATCH_NUMBER"] = @batch.number
    row_for_vaccinated_patient["BATCH_EXPIRY_DATE"] = @batch.expiry.strftime(
      "%d/%m/%Y"
    )
    row_for_vaccinated_patient["ANATOMICAL_SITE"] = "Left Upper Arm"
    row_for_vaccinated_patient["DOSE_SEQUENCE"] = "1"
    row_for_vaccinated_patient["PERFORMING_PROFESSIONAL_EMAIL"] = @team
      .users
      .first
      .email
    row_for_vaccinated_patient[
      "CLINIC_NAME"
    ] = @community_clinic.name if @community_clinic

    row_for_unvaccinated_patient =
      csv_table.find do |row|
        row["PERSON_FORENAME"] == @unvaccinated_patient.given_name &&
          row["PERSON_SURNAME"] == @unvaccinated_patient.family_name
      end
    row_for_unvaccinated_patient["DATE_OF_VACCINATION"] = Date.current.strftime(
      "%d/%m/%Y"
    )
    row_for_unvaccinated_patient["TIME_OF_VACCINATION"] = "10:01"
    row_for_unvaccinated_patient["VACCINATED"] = "N"
    row_for_unvaccinated_patient["VACCINE_GIVEN"] = "Gardasil9"
    row_for_unvaccinated_patient["REASON_NOT_VACCINATED"] = "unwell"
    row_for_unvaccinated_patient["NOTES"] = "Some notes."
    row_for_unvaccinated_patient["PERFORMING_PROFESSIONAL_EMAIL"] = @team
      .users
      .first
      .email
    row_for_unvaccinated_patient[
      "CLINIC_NAME"
    ] = @community_clinic.name if @community_clinic

    File.write("tmp/modified.csv", csv_table.to_csv)
  end

  def and_i_upload_the_modified_csv_file
    travel 1.minute

    visit "/"

    click_on "Import", match: :first
    click_on "Upload records"
    choose "Vaccination records"
    click_on "Continue"

    attach_file("immunisation_import[csv]", "tmp/modified.csv")
    click_on "Continue"

    wait_for_import_to_complete(ImmunisationImport)
  end

  def when_i_navigate_to_the_session_page
    visit "/dashboard"
    click_on "Sessions", match: :first
    choose "Scheduled"
    click_on "Update results"
    click_on @session.location.name
  end

  def when_i_navigate_to_the_clinic_page
    visit "/dashboard"
    click_on "Sessions", match: :first
    choose "Scheduled"
    click_on "Update results"
    click_on "Community clinic"
  end

  def then_i_see_the_uploaded_vaccination_outcomes_reflected_in_the_session
    within(".app-secondary-navigation") { click_on "Children" }
    choose "Vaccinated", match: :first
    click_on "Update results"

    click_on @vaccinated_patient.full_name

    expect(page).to have_content("Vaccinated")

    patient_url = current_url

    click_on "1 February 2024"
    expect(page).to have_content("Gardasil 9")
    expect(page).to have_content(@batch.number)
    expect(page).to have_content("DateToday (1 February 2024)")
    expect(page).to have_content("Time10:00am")
    expect(page).to have_content(
      "VaccinatorYou (#{@team.users.first.full_name})"
    )
    expect(page).to have_content("SiteLeft arm (upper position)")

    visit patient_url
    within(".nhsuk-breadcrumb") { click_on "Children" }
    choose "Unable to vaccinate"
    click_on "Update results"

    click_on @unvaccinated_patient.full_name
    expect(page).to have_content(@unvaccinated_patient.full_name)
    expect(page).to have_content("Unable to vaccinate")
    expect(page).to have_content("Unwell")

    visit patient_url
    within(".nhsuk-breadcrumb") { click_on "Children" }
    choose "Vaccinated", match: :first
    click_on "Update results"

    click_on @restricted_vaccinated_patient.full_name
    expect(page).to have_content(@restricted_vaccinated_patient.full_name)
    expect(page).to have_content("Vaccinated")
  end

  def and_the_clinic_location_is_displayed
    expect(page).to have_content("Westfield Shopping Centre")
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.perform_now
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    expect_email_to(
      @vaccinated_patient.consents.last.parent.email,
      :vaccination_administered,
      :any
    )

    expect_email_to(
      @unvaccinated_patient.consents.last.parent.email,
      :vaccination_not_administered,
      :any
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_vaccination
    expect_sms_to(
      @vaccinated_patient.consents.last.parent.phone,
      :vaccination_administered,
      :any
    )

    expect_sms_to(
      @unvaccinated_patient.consents.last.parent.phone,
      :vaccination_not_administered,
      :any
    )
  end

  def then_i_see_the_successful_import
    expect(page).to have_content("Completed")
    expect(page).not_to have_content("Invalid")

    expect(page).to have_content("4 imported records")
  end

  def then_i_see_a_duplicate_record_needs_review
    expect(page).to have_content("1 upload issue")
  end

  def then_i_see_that_no_records_need_review
    expect(page).not_to have_content("upload issue")
  end

  def then_i_should_see_a_success_message
    expect(page).to have_content("Record updated")
  end

  def and_the_vaccination_record_is_synced_to_nhs
    # expect(SyncVaccinationRecordToNHSJob).to have_been_enqueued.exactly(2).times
    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).to have_been_requested
  end

  def and_the_vaccination_record_is_deleted_from_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_delete_request).to have_been_requested
  end
end
