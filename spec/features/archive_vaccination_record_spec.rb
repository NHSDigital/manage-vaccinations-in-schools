# frozen_string_literal: true

describe "Archive vaccination record" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "User doesn't archive the record" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists

    when_i_sign_in_as_a_superuser
    and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    and_i_click_on_the_vaccination_record
    and_i_click_on_archive_vaccination_record
    then_i_see_the_archive_vaccination_page

    when_i_dont_archive_the_vaccination_record
    then_i_see_the_patient
    and_they_are_already_vaccinated
  end

  scenario "User archives a record and checks activity log" do
    given_an_hpv_programme_is_underway
    and_imms_api_sync_job_feature_is_enabled
    and_an_administered_vaccination_record_exists

    when_i_sign_in_as_a_superuser
    and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    and_i_click_on_the_vaccination_record
    and_i_click_on_archive_vaccination_record
    then_i_see_the_archive_vaccination_page

    when_i_archive_the_vaccination_record
    then_i_see_the_patient
    and_i_see_a_successful_message
    and_the_vaccination_record_is_deleted_from_nhs

    when_i_click_on_the_session
    then_i_see_the_patient_can_be_vaccinated

    when_i_click_on_the_log
    then_i_see_the_archive_vaccination
  end

  scenario "User archives a record before confirmation is sent" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists

    when_i_sign_in_as_a_superuser
    and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    and_i_click_on_the_vaccination_record
    and_i_click_on_archive_vaccination_record
    then_i_see_the_archive_vaccination_page

    when_i_archive_the_vaccination_record
    then_i_see_the_patient
    and_i_see_a_successful_message

    when_i_click_on_the_session
    then_i_see_the_patient_can_be_vaccinated

    when_i_click_on_the_log
    then_i_see_the_archive_vaccination
    and_the_parent_doesnt_receives_an_email
  end

  scenario "User archives a record after confirmation is sent" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists
    and_a_confirmation_email_has_been_sent

    when_i_sign_in_as_a_superuser
    and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    and_i_click_on_the_vaccination_record
    and_i_click_on_archive_vaccination_record
    then_i_see_the_archive_vaccination_page

    when_i_archive_the_vaccination_record
    then_i_see_the_patient
    and_i_see_a_successful_message

    when_i_click_on_the_session
    then_i_see_the_patient_can_be_vaccinated

    when_i_click_on_the_log
    then_i_see_the_archive_vaccination
    and_the_parent_receives_an_email
  end

  scenario "User archives a record from children page" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists

    when_i_sign_in_as_a_superuser
    and_i_go_to_a_patient_that_is_vaccinated_via_all_children
    and_i_click_on_the_vaccination_record
    and_i_click_on_archive_vaccination_record
    then_i_see_the_archive_vaccination_page

    when_i_archive_the_vaccination_record
    then_i_see_the_patient
    and_i_see_a_successful_message
    and_they_have_no_vaccinations
  end

  scenario "User can't archive a record without superuser access" do
    given_an_hpv_programme_is_underway
    and_an_administered_vaccination_record_exists

    when_i_sign_in
    and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    and_i_click_on_the_vaccination_record
    then_i_cant_click_on_archive_vaccination_record
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team =
      create(
        :team,
        :with_generic_clinic,
        :with_one_nurse,
        programmes: [@programme]
      )

    @session =
      create(
        :session,
        date: Date.yesterday,
        team: @team,
        programmes: [@programme]
      )

    @patient =
      create(
        :patient,
        :consent_given_triage_safe_to_vaccinate,
        given_name: "John",
        family_name: "Smith",
        year_group: 8,
        programmes: [@programme],
        team: @team
      )

    @patient_location =
      create(:patient_location, patient: @patient, session: @session)
  end

  def and_an_administered_vaccination_record_exists
    vaccine = @programme.vaccines.first

    batch = create(:batch, :not_expired, team: @team, vaccine:)

    @vaccination_record =
      create(
        :vaccination_record,
        programme: @programme,
        patient: @patient,
        session: @session,
        batch:
      )

    PatientStatusUpdater.call(patient: @patient)

    if Flipper.enabled?(:imms_api_integration) &&
         Flipper.enabled?(:imms_api_sync_job, @vaccination_record.programme)
      Sidekiq::Job.drain_all
      expect(@stubbed_post_request).to have_been_requested
    end

    travel 1.hour
  end

  def and_a_confirmation_email_has_been_sent
    @vaccination_record.update(confirmation_sent_at: Time.current)
  end

  def and_imms_api_sync_job_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, @programme)
    Flipper.enable(:imms_api_integration)

    uuid = Random.uuid
    @stubbed_post_request = stub_immunisations_api_post(uuid:)
    @stubbed_put_request = stub_immunisations_api_put(uuid:)
    @stubbed_delete_request = stub_immunisations_api_delete(uuid:)
  end

  def when_i_sign_in
    sign_in @team.users.first
  end

  def when_i_sign_in_as_a_superuser
    sign_in @team.users.first, superuser: true
  end

  def and_i_go_to_a_patient_that_is_vaccinated_in_the_session
    visit session_patients_path(@session)
    choose "Vaccinated", match: :first
    click_on "Update results"
    click_on @patient.full_name
  end

  def and_i_click_on_the_vaccination_record
    within(".app-secondary-navigation") { click_on @programme.name }
    click_on Date.current.to_fs(:long)
  end

  def and_i_go_to_a_patient_that_is_vaccinated_via_all_children
    visit patients_path
    check "Year 8"
    click_button "Update results"
    click_on @patient.full_name
  end

  def and_i_click_on_archive_vaccination_record
    click_on "Archive vaccination record"
  end

  def then_i_see_the_archive_vaccination_page
    expect(page).to have_content(
      "Are you sure you want to archive this vaccination record?"
    )
  end

  def when_i_dont_archive_the_vaccination_record
    click_on "No, return to patient"
  end

  def then_i_see_the_patient
    expect(page).to have_content(@patient.full_name)
  end

  def and_they_are_already_vaccinated
    expect(page).to have_content("Vaccinated")
  end

  def when_i_archive_the_vaccination_record
    click_on "Yes, archive this vaccination record"
  end

  def and_i_see_a_successful_message
    expect(page).to have_content("Vaccination record archived")
  end

  def when_i_click_on_the_session
    within(".app-secondary-navigation") { click_on @programme.name }
    click_on @session.location.name
  end

  def then_i_see_the_patient_can_be_vaccinated
    expect(page).to have_content("Safe to vaccinate")
    expect(page).not_to have_content("Vaccinated")
  end

  def and_they_have_no_vaccinations
    within(".app-secondary-navigation") { click_on @programme.name }
    expect(page).to have_content("No vaccination record")
  end

  def when_i_click_on_the_log
    click_on "Session activity and notes"
  end

  def then_i_see_the_archive_vaccination
    expect(page).to have_content("Vaccinated with Gardasil 9")
    expect(page).to have_content("Vaccination record archived")
  end

  def and_the_parent_receives_an_email
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.parents.first.email,
        template: :vaccination_deleted
      ).with_content_including("sent in error", "Please ignore it")
    )
  end

  def and_the_parent_doesnt_receives_an_email
    expect(email_deliveries).to be_empty
  end

  def then_i_cant_click_on_archive_vaccination_record
    expect(page).not_to have_content("Archive vaccination record")
  end

  def and_the_vaccination_record_is_deleted_from_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_delete_request).to have_been_requested
  end
end
