# frozen_string_literal: true

describe "HPV vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  scenario "Administered with common delivery site" do
    given_i_am_signed_in
    and_imms_api_sync_job_feature_is_enabled

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_fill_in_pre_screening_questions
    and_i_record_that_the_patient_has_been_vaccinated(
      "Left arm (upper position)"
    )
    and_i_see_only_not_expired_batches
    when_i_click_back
    then_i_see_the_patient_session_page

    and_i_record_that_the_patient_has_been_vaccinated(
      "Left arm (upper position)"
    )
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_click_change_outcome
    and_i_choose_vaccinated
    and_i_select_the_delivery
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_click_change_batch
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_click_change_delivery_site
    and_i_select_the_delivery
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_click_change_date
    and_i_select_the_date
    and_i_choose_vaccinated
    and_i_select_the_delivery
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
    and_the_disease_types_are_set_on_the_record
    and_i_can_no_longer_vaccinate_the_patient
    and_i_no_longer_see_the_patient_in_the_record_tab
    and_the_vaccination_record_is_synced_to_nhs
    and_the_parent_doesnt_receive_a_vaccination_already_had_email

    when_i_go_back
    and_i_save_changes
    then_i_see_that_the_status_is_vaccinated
    and_i_see_the_vaccination_details

    when_i_go_to_the_children_tab
    and_i_filter_by_completed_session
    then_i_see_the_patient

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Administered with other delivery site" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_fill_in_pre_screening_questions
    and_i_record_that_the_patient_has_been_vaccinated("Other")
    when_i_click_back
    then_i_see_the_patient_session_page

    and_i_record_that_the_patient_has_been_vaccinated("Other")
    and_i_select_the_delivery
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
  end

  scenario "Administered without registration" do
    given_registrations_are_not_required
    and_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_fill_in_pre_screening_questions
    and_i_record_that_the_patient_has_been_vaccinated("Other")
    and_i_select_the_delivery
    and_i_select_the_batch
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
  end

  def given_i_am_signed_in
    programme = Programme.hpv
    team = create(:team, :with_one_nurse, programmes: [programme])
    location = create(:gias_school, team:)

    programme.vaccines.discontinued.each do |vaccine|
      create(:batch, team:, vaccine:)
    end

    @active_vaccine = programme.vaccines.active.first
    @active_batch =
      create(:batch, :not_expired, team:, vaccine: @active_vaccine)
    @archived_batch = create(:batch, :archived, team:, vaccine: @active_vaccine)

    # To get around expiration date validation on the model.
    @expired_batch = build(:batch, :expired, team:, vaccine: @active_vaccine)
    @expired_batch.save!(validate: false)

    session_traits =
      @registrations_are_not_required ? [:requires_no_registration] : []
    @session =
      create(
        :session,
        *session_traits,
        team:,
        programmes: [programme],
        location:
      )
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        given_name: "John",
        family_name: "Doe",
        programmes: [programme],
        session: @session
      )
    PatientStatusUpdater.call(patient: @patient)

    sign_in team.users.first
  end

  alias_method :and_i_am_signed_in, :given_i_am_signed_in

  def given_registrations_are_not_required
    @registrations_are_not_required = true
  end

  def and_imms_api_sync_job_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, Programme.hpv)
    Flipper.enable(:imms_api_integration)

    immunisation_uuid = Random.uuid
    @stubbed_post_request = stub_immunisations_api_post(uuid: immunisation_uuid)
    @stubbed_put_request = stub_immunisations_api_put(uuid: immunisation_uuid)
  end

  def when_i_go_to_a_patient_that_is_safe_to_vaccinate
    visit session_record_path(@session)
    expect(page).not_to have_content("Default batches")
    click_link @patient.full_name
  end

  def when_i_click_back
    click_on "Back"
  end

  def and_i_fill_in_pre_screening_questions
    check "I have checked that the above statements are true"
  end

  def and_i_record_that_the_patient_has_been_vaccinated(where)
    within all("form")[3] do
      within all("fieldset")[2] do
        choose "Yes"
        choose where
      end

      click_button "Continue"
    end
  end

  def and_i_see_only_not_expired_batches
    expect(page).not_to have_content(@expired_batch.number)
    expect(page).not_to have_content(@archived_batch.number)
    expect(page).to have_content(@active_batch.number)
  end

  def and_i_select_the_batch
    choose @active_batch.number
    click_button "Continue"
  end

  def then_i_see_the_patient_session_page
    expect(page).to have_content("Session activity and notes")
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Child#{@patient.full_name}")
    expect(page).to have_content("Batch number#{@active_batch.number}")
    expect(page).to have_content("MethodIntramuscular")
    expect(page).to have_content("SiteLeft arm")
    expect(page).to have_content("OutcomeVaccinated")
  end

  def when_i_click_change_outcome
    click_on "Change outcome"
  end

  def and_i_choose_vaccinated
    choose "Vaccinated"
    click_on "Continue"
  end

  def when_i_click_change_batch
    click_on "Change batch"
  end

  def when_i_click_change_delivery_site
    click_on "Change site"
  end

  def and_i_select_the_delivery
    choose "Intramuscular"
    choose "Left arm (upper position)"
    click_on "Continue"
  end

  def when_i_click_change_date
    click_on "Change date"
  end

  def and_i_select_the_date
    click_on "Continue"
  end

  def when_i_confirm_the_details
    click_button "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end

  def and_the_disease_types_are_set_on_the_record
    expect(VaccinationRecord.last.disease_types).to contain_exactly(
      "human_papillomavirus"
    )
  end

  def and_i_can_no_longer_vaccinate_the_patient
    expect(page).not_to have_content("You still need to record an outcome")
    expect(page).not_to have_content("ready for their HPV vaccination?")
  end

  def and_i_no_longer_see_the_patient_in_the_record_tab
    click_on "Record vaccinations"
    expect(page).to have_content("No children matching search criteria found")
  end

  def when_i_go_back
    visit draft_vaccination_record_path("confirm")
  end

  def and_i_save_changes
    click_button "Save changes"
  end

  def then_i_see_that_the_status_is_vaccinated
    expect(page).to have_content("Vaccinated")
  end

  def and_i_see_the_vaccination_details
    expect(page).to have_content("Vaccination records")
    click_on Date.current.to_fs(:long)

    expect(page).to have_content("Vaccination details")
    expect(page).to have_content("Dose number1st")
  end

  def when_i_go_to_the_children_tab
    click_on "Sessions", match: :first
    click_on @session.location.name
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def and_i_filter_by_completed_session
    choose "Completed session"
    click_on "Update results"
  end

  def then_i_see_the_patient
    expect(page).to have_content(@patient.full_name)
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.perform_now
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.last.parent.email,
        subject: "Your child had their HPV vaccination today",
        template: :vaccination_administered
      ).with_content_including(
        "John Doe had their HPV vaccination at #{@session.location.name} today",
        "Vaccination: HPV",
        "Vaccine: Gardasil 9",
        "Date of vaccination: 01/02/2024",
        "swelling or pain where the injection was given",
        "a headache",
        "a high temperature",
        "dizziness",
        "feeling sick",
        "tiredness"
      )
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_vaccination
    expect_sms_to(
      @patient.consents.last.parent.phone,
      :vaccination_administered
    )
  end

  def and_the_vaccination_record_is_synced_to_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).to have_been_requested
  end

  def and_the_parent_doesnt_receive_a_vaccination_already_had_email
    expect(email_deliveries).to be_empty
  end
end
