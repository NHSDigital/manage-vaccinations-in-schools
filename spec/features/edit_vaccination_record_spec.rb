# frozen_string_literal: true

describe "Edit vaccination record" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  context "in full-fat Mavis" do
    before { given_an_hpv_programme_is_underway }

    scenario "User edits a new vaccination record" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_imms_api_sync_job_feature_is_enabled

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record
      and_i_should_see_the_correct_page_title

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_back
      then_i_should_see_the_vaccination_record
      and_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_date
      then_i_should_see_the_date_time_form

      when_i_fill_in_an_invalid_date
      then_i_see_the_date_time_form_with_errors

      when_i_fill_in_an_invalid_time
      then_i_see_the_date_time_form_with_errors

      when_i_fill_in_a_valid_date_and_time
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_date_time

      when_i_click_on_change_batch
      and_i_choose_a_batch
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_batch

      when_i_click_change_notes
      and_i_enter_some_notes
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_the_parent_doesnt_receive_an_email
      and_the_vaccination_record_is_synced_to_nhs
      and_the_records_batch_fields_are_assigned
    end

    scenario "User edits a vaccination record that already received confirmation" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_the_vaccination_confirmation_was_already_sent

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_date
      then_i_should_see_the_date_time_form

      when_i_fill_in_a_valid_date_and_time
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_date_time

      when_i_click_on_change_batch
      and_i_choose_a_batch
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_batch

      when_i_click_on_save_changes
      then_the_parent_receives_an_administered_email
      and_the_records_batch_fields_are_assigned
    end

    scenario "User edits a vaccination record, not enough to trigger an email" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_the_vaccination_confirmation_was_already_sent

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_delivery_method
      and_i_choose_a_delivery_method_and_site
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_the_parent_doesnt_receive_an_email
    end

    scenario "Edit outcome to vaccinated" do
      given_i_am_signed_in
      and_imms_api_sync_job_feature_is_enabled
      and_a_not_administered_vaccination_record_exists
      and_the_vaccination_confirmation_was_already_sent

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_outcome
      then_i_should_see_the_change_outcome_form
      and_i_choose_vaccinated
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_add_batch
      and_i_choose_a_batch
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_batch

      when_i_click_on_add_delivery_method
      and_i_choose_a_delivery_method_and_site
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_parent_receives_an_administered_email
      and_the_vaccination_record_is_synced_to_nhs
      and_the_records_batch_fields_are_assigned
    end

    scenario "Edit outcome to not vaccinated" do
      given_i_am_signed_in
      and_imms_api_sync_job_feature_is_enabled
      and_an_administered_vaccination_record_exists
      and_the_vaccination_confirmation_was_already_sent

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_outcome
      then_i_should_see_the_change_outcome_form
      and_i_choose_unwell
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_parent_receives_a_not_administered_email
      and_the_vaccination_record_is_deleted_from_nhs
    end

    scenario "With an archived batch" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_the_original_batch_has_been_archived
      and_there_exists_a_different_batch_with_the_same_number_and_expiry

      when_i_go_to_the_vaccination_record_for_the_patient
      and_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_batch
      then_i_should_not_see_the_similar_batch
      when_i_choose_the_original_batch
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_records_batch_fields_are_assigned_with_the_original_batch_details
    end

    scenario "With an expired batch" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_the_original_batch_has_expired
      and_there_exists_a_different_batch_with_the_same_number_and_expiry

      when_i_go_to_the_vaccination_record_for_the_patient
      and_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_batch
      then_i_should_not_see_the_similar_batch
      when_i_choose_the_original_batch
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_records_batch_fields_are_assigned_with_the_original_batch_details
    end

    scenario "Cannot as a medical secretary" do
      given_i_am_signed_in_as_an_admin
      and_an_administered_vaccination_record_exists

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_not_be_able_to_edit_the_vaccination_record
    end

    scenario "Navigating back" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists

      when_i_go_to_the_vaccination_record_for_the_patient
      and_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record

      when_i_go_back_to_the_confirm_page
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "User edits a service-created vaccination record and no discovered email is sent" do
      given_i_am_signed_in
      and_a_not_administered_vaccination_record_exists
      and_the_patient_has_consent_but_no_prior_discovered_notification

      when_i_go_to_the_vaccination_record_for_the_patient
      and_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_outcome
      then_i_should_see_the_change_outcome_form
      and_i_choose_vaccinated
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_add_batch
      and_i_choose_a_batch
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_batch

      when_i_click_on_add_delivery_method
      and_i_choose_a_delivery_method_and_site
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_parent_doesnt_receive_a_vaccination_already_had_email
      and_the_records_batch_fields_are_assigned
    end

    scenario "Patient has an existing delayed triage and user edit's vaccination record date" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_a_delayed_triage_exists

      when_i_go_to_the_vaccination_record_for_the_patient
      and_i_click_on_edit_vaccination_record

      when_i_click_on_change_date
      then_i_should_see_the_date_time_form

      when_i_fill_in_a_valid_date_and_time
      and_i_click_on_save_changes
      then_the_delayed_triage_is_updated_accordingly
    end

    scenario "Parent details are visible when viewing vaccination records" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists
      and_the_patient_has_parents

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record
      and_i_should_see_parent_details
    end

    scenario "Breadcrumb shows session-specific path for point of care team" do
      given_i_am_signed_in
      and_an_administered_vaccination_record_exists

      when_i_visit_the_vaccination_record_directly
      then_i_should_see_the_vaccination_record
      and_i_should_see_the_session_specific_breadcrumb
    end
  end

  context "in national reporting Mavis" do
    before { given_a_national_reporting_team_exists }

    scenario "National reporting user edits a national reporting uploaded vaccination record" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page
      and_i_should_not_see_a_change_outcome_link

      when_i_click_back
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page
      and_i_should_not_see_a_change_outcome_link

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "Edits the vaccinator" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_navigate_to_the_edit_vaccination_record_page

      when_i_edit_the_vaccinator
      and_i_enter_a_new_first_name_and_last_name
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_vaccinator_details

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "Edits dose number" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_navigate_to_the_edit_vaccination_record_page

      when_i_click_on_change_dose_number
      and_i_choose_the_second_dose
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_dose_number

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "Edits the location" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_navigate_to_the_edit_vaccination_record_page

      when_i_click_on_change_location
      and_i_choose_location_unknown
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_location_unknown

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_location
      and_i_choose_a_school
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_location

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "Edits the batch" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_navigate_to_the_edit_vaccination_record_page

      when_i_click_on_change_batch
      then_i_should_see_the_batch_form

      when_i_click_back
      and_i_click_on_change_vaccine
      then_i_should_see_the_batch_form

      when_i_click_back
      and_i_click_on_change_batch_expiry_date
      then_i_should_see_the_batch_form

      when_i_enter_an_empty_batch_name
      then_i_should_see_the_batch_form
      and_i_should_see_an_error_message_for_batch_name

      when_i_enter_an_empty_day
      then_i_should_see_the_batch_form
      and_i_should_see_an_error_message_for_day

      when_i_enter_batch_details
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_national_reporting_updated_batch

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
    end

    scenario "Edits the date and time with or without time" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists

      when_i_navigate_to_the_edit_vaccination_record_page

      when_i_click_on_change_date
      then_i_should_see_the_date_time_form

      when_i_fill_in_a_valid_date_with_time
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_date_with_time

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_vaccination_record_should_have_the_time

      when_i_click_on_edit_vaccination_record
      then_i_see_the_edit_vaccination_record_page

      when_i_click_on_change_date
      then_i_should_see_the_date_time_form

      when_i_fill_in_a_valid_date_without_time
      then_i_see_the_edit_vaccination_record_page
      and_i_should_see_the_updated_date_without_time

      when_i_click_on_save_changes
      then_i_should_see_the_vaccination_record
      and_the_vaccination_record_should_have_no_time
    end

    scenario "Parent details are not visible when viewing vaccination records" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists
      and_the_patient_has_parents

      when_i_go_to_the_vaccination_record_for_the_patient
      then_i_should_see_the_vaccination_record
      and_i_should_not_see_parent_details
    end

    scenario "Breadcrumb shows patient-based path when viewing session-based vaccination record" do
      given_i_am_signed_in
      and_a_vaccination_record_with_a_session_exists
      and_the_patient_is_accessible_to_the_national_reporting_team

      when_i_visit_the_vaccination_record_directly
      then_i_should_see_the_vaccination_record
      and_i_should_see_the_patient_based_breadcrumb
    end

    scenario "User edits two vaccination records with different delivery methods" do
      given_i_am_signed_in
      and_a_national_reporting_vaccination_record_exists
      and_a_vaccination_record_with_a_different_delivery_method_exists

      when_i_visit_the_first_vaccination_record_directly
      and_i_click_on_edit_vaccination_record

      and_i_visit_the_flu_vaccination_record_directly
      and_i_click_on_edit_vaccination_record
      and_i_click_on_save_changes

      then_i_should_see_a_success_message
    end
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @other_programme = Programme.flu

    @team =
      create(
        :team,
        :with_one_nurse,
        ods_code: "R1L",
        programmes: [@programme, @other_programme]
      )

    @vaccine = @programme.vaccines.first

    @original_batch =
      create(:batch, :not_expired, team: @team, vaccine: @vaccine)
    @replacement_batch =
      create(:batch, :not_expired, team: @team, vaccine: @vaccine)

    location = create(:school, team: @team)

    @session =
      create(
        :session,
        :completed,
        team: @team,
        programmes: [@programme],
        location:
      )

    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        given_name: "John",
        family_name: "Smith",
        team: @team,
        session: @session,
        year_group: 8
      )
  end

  def given_a_national_reporting_team_exists
    @programme = Programme.hpv

    @team =
      create(
        :team,
        :with_one_admin,
        :national_reporting,
        ods_code: "R1L",
        programmes: [Programme.hpv, Programme.flu]
      )

    @patient =
      create(
        :patient,
        :in_national_reporting_upload,
        given_name: "John",
        family_name: "Smith",
        team: @team,
        session: @session,
        year_group: 8
      )

    @school = create(:school, name: "A New School", status: "open")

    @vaccine = @programme.vaccines.first
    @new_vaccine = @programme.vaccines.second

    @batch =
      create(
        :batch,
        team: @team,
        vaccine: @vaccine,
        expiry: Date.new(2026, 1, 1)
      )
  end

  def given_i_am_signed_in
    sign_in @team.users.first
  end

  def given_i_am_signed_in_as_an_admin
    sign_in @team.users.first, role: :medical_secretary
  end

  def and_an_administered_vaccination_record_exists
    @vaccination_record =
      create(
        :vaccination_record,
        batch: @original_batch,
        vaccine: @original_batch.vaccine,
        patient: @patient,
        session: @session,
        programme: @programme
      )

    Sidekiq::Job.drain_all if Flipper.enabled?(:imms_api_integration)
  end

  def and_a_national_reporting_vaccination_record_exists
    @vaccination_record =
      create(
        :vaccination_record,
        :sourced_from_national_reporting,
        uploaded_by: @team.users.first,
        batch: @batch,
        vaccine: @batch.vaccine,
        patient: @patient,
        programme: @programme,
        performed_by_user: nil,
        performed_by_given_name: "Albus",
        performed_by_family_name: "Dumbledore"
      )
  end

  def and_a_vaccination_record_with_a_different_delivery_method_exists
    @flu_programme = Programme.flu
    @flu_vaccine = @flu_programme.vaccines.first
    @flu_batch =
      create(:batch, :not_expired, team: @team, vaccine: @flu_vaccine)

    @flu_vaccination_record =
      create(
        :vaccination_record,
        :sourced_from_national_reporting,
        uploaded_by: @team.users.first,
        delivery_method: :nasal_spray,
        delivery_site: :nose,
        batch: @flu_batch,
        vaccine: @flu_batch.vaccine,
        patient: @patient,
        programme: @flu_programme,
        performed_by_user: nil,
        performed_by_given_name: "Albus",
        performed_by_family_name: "Dumbledore"
      )

    expect(@flu_vaccination_record.delivery_method).not_to eq(
      @vaccination_record.delivery_method
    )
  end

  def and_a_delayed_triage_exists
    delay_date = @vaccination_record.performed_at + 28.days
    @delayed_triage =
      create(
        :triage,
        patient: @patient,
        team: @session.team,
        programme: @programme,
        performed_by: @team.users.first,
        status: "delay_vaccination",
        academic_year: @session.academic_year,
        notes: "Next dose #{delay_date.strftime("%d %B %Y")}",
        delay_vaccination_until: delay_date
      )
    @vaccination_record.update!(next_dose_delay_triage: @delayed_triage)
  end

  def and_imms_api_sync_job_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, @programme)
    Flipper.enable(:imms_api_integration)

    uuid = Random.uuid
    @stubbed_post_request = stub_immunisations_api_post(uuid:)
    @stubbed_put_request = stub_immunisations_api_put(uuid:)
    @stubbed_delete_request = stub_immunisations_api_delete(uuid:)
  end

  def and_an_historical_administered_vaccination_record_exists
    @vaccination_record =
      create(
        :vaccination_record,
        batch: @original_batch,
        patient: @patient,
        session: @session,
        performed_by_family_name: "Joy",
        performed_by_given_name: "Nurse",
        performed_by_user: nil,
        programme: @programme
      )
  end

  def and_a_not_administered_vaccination_record_exists
    @vaccination_record =
      create(
        :vaccination_record,
        :not_administered,
        batch_number: @original_batch.number,
        batch_expiry: @original_batch.expiry,
        patient: @patient,
        session: @session,
        programme: @programme
      )

    if Flipper.enabled?(:imms_api_integration) &&
         Flipper.enabled?(:imms_api_sync_job, @vaccination_record.programme)
      Sidekiq::Job.drain_all
    end
  end

  def and_the_vaccination_confirmation_was_already_sent
    @vaccination_record.update!(confirmation_sent_at: Time.current)
  end

  def and_the_original_batch_has_been_archived
    @original_batch.update!(archived_at: Time.current)
  end

  def and_the_original_batch_has_expired
    @original_batch.expiry = 1.day.ago
    @original_batch.save!(validate: false)

    @vaccination_record.batch_expiry = @original_batch.expiry
    @vaccination_record.save!
  end

  def and_there_exists_a_different_batch_with_the_same_number_and_expiry
    @different_batch =
      create(
        :batch,
        team: @original_batch.team,
        number: @original_batch.number,
        expiry: @original_batch.expiry,
        vaccine: @other_programme.vaccines.first
      )
  end

  def when_i_go_to_the_vaccination_record_for_the_patient
    visit "/dashboard"

    click_on "Children", match: :first
    fill_in "Search", with: @patient.full_name
    find("button.app-search-input__button").click

    click_on @patient.full_name
    unless @team.has_national_reporting_access?
      within(".app-secondary-navigation") { click_on @programme.name }
    end
    click_on Date.current.to_fs(:long)
  end

  def then_i_should_see_the_vaccination_record
    expect(page).to have_content("Full nameSMITH, John")
  end

  def and_i_should_see_the_correct_page_title
    expect(page.title).to include("JS – HPV")
  end

  def when_i_click_on_edit_vaccination_record
    click_on "Edit vaccination record"
  end

  alias_method :and_i_click_on_edit_vaccination_record,
               :when_i_click_on_edit_vaccination_record

  def then_i_see_the_edit_vaccination_record_page
    expect(page).to have_content("Edit vaccination record")
    expect(page).not_to have_content(
      "The vaccine given does not match that determined by the child's consent or triage outcome"
    )
  end

  def when_i_navigate_to_the_edit_vaccination_record_page
    when_i_go_to_the_vaccination_record_for_the_patient
    then_i_should_see_the_vaccination_record

    when_i_click_on_edit_vaccination_record
    then_i_see_the_edit_vaccination_record_page
  end

  def when_i_click_back
    click_on "Back"
  end

  def when_i_edit_the_vaccinator
    click_on "Change vaccinator"
  end

  def and_i_enter_a_new_first_name_and_last_name
    fill_in "First name", with: "New"
    fill_in "Last name", with: "Name"
    click_on "Continue"
  end

  def and_i_should_see_the_updated_vaccinator_details
    expect(page).to have_content("VaccinatorNAME, New")
  end

  def when_i_click_on_change_dose_number
    click_on "Change dose number"
  end

  def and_i_choose_the_second_dose
    choose "2nd"
    click_on "Continue"
  end

  def and_i_should_see_the_updated_dose_number
    expect(page).to have_content("Dose number2nd")
  end

  def when_i_click_on_change_date
    click_on "Change date"
  end

  def then_i_should_see_the_date_time_form
    expect(page).to have_content("Date")
    expect(page).to have_content("Time")
  end

  def when_i_fill_in_a_valid_date_and_time
    @valid_date = Date.current - 1.day

    fill_in "Year", with: @valid_date.year.to_s
    fill_in "Month", with: @valid_date.month.to_s
    fill_in "Day", with: @valid_date.day.to_s

    fill_in "Hour", with: "12"
    fill_in "Minute", with: "00"

    click_on "Continue"
  end

  def when_i_fill_in_an_invalid_date
    fill_in "Year", with: "3023"
    fill_in "Month", with: "19"
    fill_in "Day", with: "33"

    fill_in "Hour", with: "23"
    fill_in "Minute", with: "15"

    click_on "Continue"
  end

  def when_i_fill_in_an_invalid_time
    fill_in "Year", with: "2025"
    fill_in "Month", with: "5"
    fill_in "Day", with: "1"

    fill_in "Hour", with: "25"
    fill_in "Minute", with: "61"

    click_on "Continue"
  end

  def then_i_see_the_date_time_form_with_errors
    expect(page).to have_content("There is a problem")
  end

  def and_i_should_see_the_updated_date_time
    formatted_date = @valid_date.strftime("%-d %B %Y")

    expect(page).to have_content("Date#{formatted_date}")
    expect(page).to have_content("Time12:00pm")
  end

  def when_i_click_change_vaccine
    click_on "Change vaccine"
  end

  def when_i_click_on_change_batch
    click_on "Change batch"
  end

  def when_i_choose_the_original_batch
    choose @original_batch.number
    click_on "Continue"
  end

  def and_i_choose_a_batch
    choose @replacement_batch.number
    click_on "Continue"
  end

  def and_i_should_see_the_updated_batch
    expect(page).to have_content("Batch number#{@replacement_batch.number}")
  end

  def when_i_click_change_notes
    click_on "Add notes"
  end

  def and_i_enter_some_notes
    fill_in "Notes", with: "Some notes."
    click_on "Continue"
  end

  def when_i_click_on_change_outcome
    click_on "Change outcome"
  end

  def and_i_should_not_see_a_change_outcome_link
    expect(page).not_to have_link("Change outcome")
  end

  def then_i_should_see_the_change_outcome_form
    expect(page).to have_content("Vaccination outcome")
  end

  def and_i_choose_vaccinated
    choose "Vaccinated"
    click_on "Continue"
  end

  def and_i_choose_unwell
    choose "They were not well enough"
    click_on "Continue"
  end

  def when_i_click_on_add_vaccine
    # vaccine is already populated for us as there is only one
    click_on "Change vaccine"
  end

  def when_i_click_on_add_batch
    click_on "Add batch"
  end

  def when_i_click_on_add_delivery_method
    click_on "Add method"
  end

  def when_i_click_on_change_delivery_method
    click_on "Change method"
  end

  def and_i_choose_a_delivery_method_and_site
    choose "Intramuscular"
    choose "Left arm (upper position)"
    click_on "Continue"
  end

  def when_i_click_on_change_location
    click_on "Change location"
  end

  def and_i_choose_location_unknown
    find("summary", text: "Vaccination location unknown").click
    click_on "Set vaccination location to unknown"
  end

  def and_i_should_see_location_unknown
    expect(page).to have_content("LocationUnknown")
  end

  def and_i_choose_a_school
    fill_in "Search for a school", with: "A New School"
    click_on "Search"
    choose "A New School"
    click_on "Continue"
  end

  def and_i_should_see_the_updated_location
    expect(page).to have_content("LocationA New School")
  end

  def then_i_should_not_see_the_similar_batch
    expect(page).not_to have_content(@different_batch.vaccine.brand)
  end

  def and_i_click_on_change_vaccine
    click_on "Change vaccine"
  end

  def and_i_click_on_change_batch_expiry_date
    click_on "Change batch expiry date"
  end

  def then_i_should_see_the_batch_form
    expect(page).to have_content("Which vaccine and batch did you use?")
    expect(page).to have_content("Vaccine")
    expect(page).to have_content("Batch number")
    expect(page).to have_content("Batch expiry date")
  end

  def when_i_enter_an_empty_batch_name
    fill_in "Batch number", with: ""

    click_on "Continue"
  end

  def and_i_should_see_an_error_message_for_batch_name
    expect(page).to have_content("Enter a batch number")
  end

  def when_i_enter_an_empty_day
    fill_in "Day", with: ""

    click_on "Continue"
  end

  def and_i_should_see_an_error_message_for_day
    expect(page).to have_content("Enter a day")
  end

  def when_i_enter_batch_details
    choose @new_vaccine.nivs_name
    fill_in "Batch number", with: "NEWBATCH123"
    fill_in "Day", with: "1"
    fill_in "Month", with: "12"
    fill_in "Year", with: "2027"

    click_on "Continue"
  end

  def and_i_should_see_the_national_reporting_updated_batch
    expect(page).to have_content("Vaccine#{@new_vaccine.nivs_name}")
    expect(page).to have_content("Batch numberNEWBATCH123")
    expect(page).to have_content("Batch expiry date1 December 2027")
  end

  def when_i_click_on_save_changes
    travel 1.minute
    click_on "Save changes"
  end

  alias_method :and_i_click_on_save_changes, :when_i_click_on_save_changes

  def then_the_parent_doesnt_receive_an_email
    expect(email_deliveries).to be_empty
  end

  alias_method :and_the_parent_doesnt_receive_an_email,
               :then_the_parent_doesnt_receive_an_email

  def and_the_parent_receives_a_not_administered_email
    expect_email_to(@patient.parents.first.email, :vaccination_not_administered)
  end

  def then_the_parent_receives_an_administered_email
    expect_email_to(@patient.parents.first.email, :vaccination_administered)
  end

  alias_method :and_the_parent_receives_an_administered_email,
               :then_the_parent_receives_an_administered_email

  def then_i_should_not_be_able_to_edit_the_vaccination_record
    expect(page).not_to have_content("Edit vaccination record")
  end

  def when_i_go_back_to_the_confirm_page
    visit draft_vaccination_record_path(id: "confirm")
  end

  def and_the_vaccination_record_is_synced_to_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).to have_been_requested
  end

  def and_the_vaccination_record_is_deleted_from_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_delete_request).to have_been_requested
  end

  def and_the_records_batch_fields_are_assigned
    @vaccination_record.reload

    expect(@vaccination_record.batch_number).to eq(@replacement_batch.number)
    expect(@vaccination_record.batch_expiry).to eq(@replacement_batch.expiry)
  end

  def and_the_records_batch_fields_are_assigned_with_the_original_batch_details
    @vaccination_record.reload

    expect(@vaccination_record.batch_number).to eq(@original_batch.number)
    expect(@vaccination_record.batch_expiry).to eq(@original_batch.expiry)
  end

  def and_the_patient_has_consent_but_no_prior_discovered_notification
    create(:consent, :given, patient: @patient, programme: @programme)
  end

  def and_the_parent_doesnt_receive_a_vaccination_already_had_email
    expect(email_deliveries).to be_empty
  end

  def then_the_delayed_triage_is_updated_accordingly
    expected_delay_date = @valid_date + 28.days

    expect(@delayed_triage.reload.delay_vaccination_until).to eq(
      expected_delay_date
    )

    expect(@delayed_triage.notes).to eq(
      "Next dose #{expected_delay_date.strftime("%d %B %Y")}"
    )
  end

  def and_the_patient_has_parents
    @parent =
      create(:parent, email: "parent@example.com", full_name: "Jane Smith")
    create(:parent_relationship, patient: @patient, parent: @parent)
  end

  def and_i_should_see_parent_details
    expect(page).to have_content("First parent or guardian")
    expect(page).to have_content("Jane Smith")
  end

  def and_i_should_not_see_parent_details
    expect(page).not_to have_content("First parent or guardian")
    expect(page).not_to have_content("Second parent or guardian")
  end

  def when_i_visit_the_vaccination_record_directly
    visit vaccination_record_path(@vaccination_record)
  end

  alias_method :when_i_visit_the_first_vaccination_record_directly,
               :when_i_visit_the_vaccination_record_directly

  def and_i_visit_the_flu_vaccination_record_directly
    visit vaccination_record_path(@flu_vaccination_record)
  end

  def and_i_should_see_the_session_specific_breadcrumb
    breadcrumb = page.find(".nhsuk-breadcrumb")
    expect(breadcrumb).to have_content("Sessions")
    expect(breadcrumb).to have_content(@session.location.name)
  end

  def and_a_vaccination_record_with_a_session_exists
    location = create(:school, urn: 100_001)

    @session = create(:session, :completed, programmes: [@programme], location:)

    @vaccination_record =
      create(
        :vaccination_record,
        batch: @batch,
        patient: @patient,
        session: @session,
        programme: @programme
      )
  end

  def and_the_patient_is_accessible_to_the_national_reporting_team
    # Patient is already part of the national reporting team from the before block
    # Just ensure patient_team association exists
    PatientTeam.find_or_create_by!(patient: @patient, team: @team)
  end

  def and_i_should_see_the_patient_based_breadcrumb
    # Patient-based breadcrumb should include: Home → Children → Patient name
    # Should NOT include session-specific links (Sessions, Location name)
    breadcrumb = page.find(".nhsuk-breadcrumb")
    expect(breadcrumb).to have_content("Children")
    expect(breadcrumb).not_to have_content("Sessions")
  end

  def when_i_edit_the_first_vaccination_record
    visit vaccination_record_path(@vaccination_record)

    click_on "Edit vaccination record"
    click_on "Save changes"
  end

  def then_i_should_see_a_success_message
    expect(page).to have_alert(
      "Success",
      text: "Vaccination outcome recorded for flu"
    )
  end

  def when_i_fill_in_a_valid_date_with_time
    @valid_date = Date.current - 1.day
    @valid_time_hour = "14"
    @valid_time_minute = "30"

    fill_in "Year", with: @valid_date.year.to_s
    fill_in "Month", with: @valid_date.month.to_s
    fill_in "Day", with: @valid_date.day.to_s

    fill_in "Hour", with: @valid_time_hour
    fill_in "Minute", with: @valid_time_minute

    click_on "Continue"
  end

  def and_i_should_see_the_updated_date_with_time
    formatted_date = @valid_date.strftime("%-d %B %Y")

    expect(page).to have_content("Date#{formatted_date}")
    expect(page).to have_content("Time2:30pm")
  end

  def and_the_vaccination_record_should_have_the_time
    @vaccination_record.reload
    expect(@vaccination_record.performed_at_time).not_to be_nil
    expect(@vaccination_record.performed_at_time.hour).to eq(14)
    expect(@vaccination_record.performed_at_time.min).to eq(30)
    expect(@vaccination_record.performed_at_date).to eq(@valid_date)
  end

  def when_i_fill_in_a_valid_date_without_time
    @valid_date = Date.current - 1.day

    fill_in "Year", with: @valid_date.year.to_s
    fill_in "Month", with: @valid_date.month.to_s
    fill_in "Day", with: @valid_date.day.to_s

    fill_in "Hour", with: ""
    fill_in "Minute", with: ""

    click_on "Continue"
  end

  def and_i_should_see_the_updated_date_without_time
    formatted_date = @valid_date.strftime("%-d %B %Y")

    expect(page).to have_content("Date#{formatted_date}")
    expect(page).not_to have_content(/Time\d/)
  end

  def and_the_vaccination_record_should_have_no_time
    @vaccination_record.reload
    expect(@vaccination_record.performed_at_time).to be_nil
    expect(@vaccination_record.performed_at_date).to eq(@valid_date)
  end
end
