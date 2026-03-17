# frozen_string_literal: true

describe "Flu vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 10, 1)) { example.run } }

  scenario "Administered with nasal spray" do
    given_i_am_signed_in_with_flu_programme
    and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    and_there_are_nasal_and_injection_batches
    and_imms_api_sync_job_feature_is_enabled

    when_i_go_to_the_nasal_only_patient
    then_i_see_the_vaccination_form_for_nasal_spray

    when_i_record_that_the_patient_has_been_vaccinated_with_nasal_spray
    then_i_see_the_check_and_confirm_page_for_nasal_spray
    and_i_get_confirmation_after_recording
    and_the_vaccination_record_is_synced_to_nhs
    and_the_parent_doesnt_receive_a_vaccination_already_had_email

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Administered with injection" do
    given_i_am_signed_in_with_flu_programme
    and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    and_there_are_nasal_and_injection_batches

    when_i_go_to_the_injection_only_patient
    then_i_see_the_vaccination_form_for_injection

    when_i_record_that_the_patient_has_been_vaccinated_with_injection
    then_i_see_the_check_and_confirm_page_for_injection
    and_i_get_confirmation_after_recording
    and_the_parent_doesnt_receive_a_vaccination_already_had_email

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Administered with nasal where injection is an option" do
    given_i_am_signed_in_with_flu_programme
    and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    and_there_are_nasal_and_injection_batches

    when_i_go_to_the_nasal_or_injection_patient
    then_i_see_the_vaccination_form_for_nasal_spray
    and_i_see_the_option_to_administer_injection

    when_i_dont_confirm_identity_check_but_dont_enter_who
    then_i_see_the_vaccination_form_for_nasal_spray
    and_i_see_the_option_to_administer_injection

    when_i_record_that_the_patient_has_been_vaccinated_with_nasal_spray(
      check_injection_first: true
    )
    then_i_see_the_check_and_confirm_page_for_nasal_spray
    and_i_get_confirmation_after_recording

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Administered with injection instead of nasal" do
    given_i_am_signed_in_with_flu_programme
    and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    and_there_are_nasal_and_injection_batches

    when_i_go_to_the_nasal_or_injection_patient
    then_i_see_the_vaccination_form_for_nasal_spray
    and_i_see_the_option_to_administer_injection

    when_i_record_that_the_patient_has_been_vaccinated_with_injection_instead
    then_i_see_the_check_and_confirm_page_for_injection
    and_i_get_confirmation_after_recording

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "Switching between nasal and injection" do
    given_i_am_signed_in_with_flu_programme
    and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    and_there_are_nasal_and_injection_batches

    when_i_go_to_the_nasal_only_patient
    then_i_see_the_vaccination_form_for_nasal_spray

    when_i_record_that_the_patient_has_been_vaccinated_with_nasal_spray
    then_i_see_the_check_and_confirm_page_for_nasal_spray

    when_i_change_the_vaccine_method_to_injection
    and_i_pick_a_batch_for_injection
    then_i_see_the_check_and_confirm_page_for_injection
    and_i_am_warned_that_the_vaccine_method_does_not_match_the_consent_and_triage
  end

  def given_i_am_signed_in_with_flu_programme
    @programme = Programme.flu
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @location = create(:school, team: @team)
    @session =
      create(
        :session,
        team: @team,
        programmes: [@programme],
        location: @location
      )
    sign_in @team.users.first
  end

  def and_there_is_a_flu_session_today_with_patients_safe_to_vaccinate
    @nasal_only_patient =
      create(
        :patient,
        :consent_given_nasal_only_triage_not_needed,
        :in_attendance,
        session: @session
      )
    @nasal_or_injection_patient =
      create(
        :patient,
        :consent_given_nasal_or_injection_triage_not_needed,
        :in_attendance,
        session: @session
      )
    @injection_patient =
      create(
        :patient,
        :consent_given_without_gelatine_triage_not_needed,
        :in_attendance,
        session: @session
      )
  end

  def and_there_are_nasal_and_injection_batches
    @nasal_vaccine = @programme.vaccines.find_by!(method: "nasal")
    @nasal_batch =
      create(:batch, :not_expired, team: @team, vaccine: @nasal_vaccine)

    @injection_vaccine = @programme.vaccines.find_by!(method: "injection")
    @injection_batch =
      create(:batch, :not_expired, team: @team, vaccine: @injection_vaccine)
  end

  def and_imms_api_sync_job_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, Programme.flu)
    Flipper.enable(:imms_api_integration)

    @stubbed_post_request = stub_immunisations_api_post
  end

  def when_i_go_to_the_nasal_only_patient
    @patient = @nasal_only_patient

    visit session_record_path(@session)

    check "Nasal spray only"
    click_on "Update results"

    click_link @patient.full_name
  end

  def when_i_go_to_the_nasal_or_injection_patient
    @patient = @nasal_or_injection_patient

    visit session_record_path(@session)

    uncheck "Nasal spray only"
    click_on "Update results"

    click_link @patient.full_name
  end

  def when_i_go_to_the_injection_only_patient
    @patient = @injection_patient

    visit session_record_path(@session)

    check "Injection only"
    click_on "Update results"

    click_link @patient.full_name
  end

  def then_i_see_the_vaccination_form_for_nasal_spray
    expect(page).to have_content("Record flu vaccination with nasal spray")
    expect(page).to have_content(
      "Is #{@patient.given_name} ready for their flu nasal spray?"
    )
  end

  def then_i_see_the_vaccination_form_for_injection
    expect(page).to have_content(
      "Record flu vaccination with gelatine-free injection"
    )
    expect(page).to have_content(
      "Is #{@patient.given_name} ready for their flu injection?"
    )
  end

  def and_i_see_the_option_to_administer_injection
    expect(page).to have_content(
      "No — but they can have the injected flu instead"
    )
  end

  def when_i_dont_confirm_identity_check_but_dont_enter_who
    choose "No, it was confirmed by somebody else"
    choose "No"
    click_on "Continue"
  end

  def when_i_record_that_the_patient_has_been_vaccinated_with_nasal_spray(
    check_injection_first: false
  )
    within all("section")[0] do
      check "I have checked that the above statements are true"
      choose "Yes" # confirmed identity
    end

    # Check that I can change my mind injection to nasal.
    if check_injection_first
      within all("section")[1] do
        choose "No — but they can have the injected flu instead"
        choose "Left arm (upper position)"
      end
    end

    within all("section")[1] do
      choose "Yes"
      click_button "Continue"
    end

    choose @nasal_batch.number
    click_button "Continue"

    expect(page).not_to have_content("Did they get the full dose?")
  end

  def when_i_record_that_the_patient_has_been_vaccinated_with_injection
    within all("section")[0] do
      check "I have checked that the above statements are true"
    end

    within all("section")[1] do
      choose "Yes"
      choose "Left arm (upper position)"
      click_button "Continue"
    end

    choose @injection_batch.number
    click_button "Continue"
  end

  def when_i_record_that_the_patient_has_been_vaccinated_with_injection_instead
    within all("section")[0] do
      check "I have checked that the above statements are true"
    end

    within all("section")[1] do
      choose "No — but they can have the injected flu instead"
      choose "Left arm (upper position)"
      click_button "Continue"
    end

    choose @injection_batch.number
    click_button "Continue"
  end

  def then_i_see_the_check_and_confirm_page_for_nasal_spray
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content(@patient.full_name)
    expect(page).to have_content(@nasal_batch.number)
    expect(page).to have_content("Nasal spray")
    expect(page).to have_content("Nose")
    expect(page).to have_content("Dose volume0.2 ml")
    expect(page).to have_content(@location.name)
    expect(page).to have_content("Vaccinated")
  end

  def and_i_get_confirmation_after_recording
    click_button "Confirm"
    expect(page).to have_content("Vaccination outcome recorded for flu")
  end

  def then_i_see_the_check_and_confirm_page_for_injection
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content(@patient.full_name)
    expect(page).to have_content(@injection_batch.number)
    expect(page).to have_content("Intramuscular")
    expect(page).to have_content("Left arm (upper position)")
    expect(page).to have_content(@location.name)
    expect(page).to have_content("Vaccinated")
  end

  def when_i_change_the_vaccine_method_to_injection
    click_link "Change method"
    choose "Intramuscular"
    choose "Left arm (upper position)"
    click_button "Continue"
  end

  def and_i_pick_a_batch_for_injection
    expect(page).not_to have_content(@nasal_batch.number)
    expect(page).not_to have_checked_field
    choose @injection_batch.number
    click_button "Continue"
  end

  def and_i_am_warned_that_the_vaccine_method_does_not_match_the_consent_and_triage
    expect(page).to have_content("Incorrect vaccine given")
    expect(page).to have_content(
      "The vaccine given does not match that determined by the child’s " \
        "consent or triage outcome"
    )
  end

  def and_the_vaccination_record_is_synced_to_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).to have_been_requested
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.perform_now
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.last.parent.email,
        template: :vaccination_administered_flu
      ).with_content_including("Vaccination: flu", "Possible side effects")
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_vaccination
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @patient.consents.last.parent.phone,
        template: :vaccination_administered
      ).with_content_including("had their", "side effects")
    )
  end

  def and_the_parent_doesnt_receive_a_vaccination_already_had_email
    expect(email_deliveries).to be_empty
  end
end
