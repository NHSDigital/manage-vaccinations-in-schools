# frozen_string_literal: true

describe "Invalidate consent" do
  scenario "Already given" do
    given_i_am_signed_in
    and_consent_has_been_given

    when_i_go_to_the_patient
    then_i_see_the_patient
    and_i_see_the_consent
    and_the_patient_is_ready_for_the_nurse

    when_i_click_on_the_consent
    then_i_see_the_consent
    and_i_click_invalidate_consent

    when_i_fill_in_the_notes
    and_i_click_invalidate_consent
    then_i_see_the_consent_has_been_invalidated
    and_i_cant_mark_as_invalid

    when_i_click_back
    then_i_see_the_patient
    and_i_see_the_consent
    and_i_am_not_able_to_record_a_vaccination
  end

  scenario "Already given and triaged" do
    given_i_am_signed_in
    and_consent_has_been_given
    and_triaged_as_safe_to_vaccinate

    when_i_go_to_the_patient
    then_i_see_the_patient
    and_i_see_the_consent
    and_the_patient_is_safe_to_vaccinate

    when_i_click_on_the_consent
    then_i_see_the_consent
    and_i_click_invalidate_consent

    when_i_fill_in_the_notes
    and_i_click_invalidate_consent
    then_i_see_the_consent_has_been_invalidated
    and_i_cant_mark_as_invalid

    when_i_click_back
    then_i_see_the_patient
    and_i_see_the_consent
    and_i_am_not_able_to_record_a_vaccination
  end

  scenario "Given self consent, and requested parents aren't notified, and vaccinated, then invalidate" do
    given_i_am_signed_in
    and_the_api_feature_flag_is_enabled
    and_self_consent_has_been_given_with_no_parent_notification

    when_the_patient_has_been_vaccinated_with_no_parent_notification
    then_the_record_is_not_synced_to_the_imms_api

    when_i_go_to_the_patient
    then_i_see_the_self_consent

    when_i_click_on_the_self_consent
    and_i_click_invalidate_consent

    when_i_fill_in_the_notes
    and_i_click_invalidate_consent
    then_i_see_the_consent_has_been_invalidated
    and_the_vaccination_record_is_updated_to_notify_parents_true
    and_the_vaccination_record_is_synced_to_the_imms_api
  end

  def given_i_am_signed_in
    @programme = Programme.hpv
    team = create(:team, :with_one_nurse, programmes: [@programme])
    @session = create(:session, team:, programmes: [@programme])
    @patient = create(:patient, session: @session)

    sign_in team.users.first
  end

  def and_the_api_feature_flag_is_enabled
    Flipper.enable(:imms_api_sync_job, @programme)
    Flipper.enable(:imms_api_integration)
  end

  def and_consent_has_been_given
    @consent =
      create(:consent, :given, patient: @patient, programme: @programme)
    PatientStatusUpdater.call(patient: @patient.reload)
    @parent = @consent.parent
  end

  def and_triaged_as_safe_to_vaccinate
    create(
      :triage,
      :safe_to_vaccinate,
      patient: @patient,
      programme: @programme
    )
    PatientStatusUpdater.call(patient: @patient.reload)
  end

  def when_i_go_to_the_patient
    visit session_patients_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_the_patient
    expect(page).to have_content(@patient.full_name)
  end

  def then_i_see_the_consent
    expect(page).to have_content(@parent.full_name)
  end

  alias_method :and_i_see_the_consent, :then_i_see_the_consent

  def and_the_patient_is_ready_for_the_nurse
    expect(page).to have_content("ready for the vaccinator")
  end

  def and_the_patient_is_safe_to_vaccinate
    expect(page).to have_content("Safe to vaccinate")
  end

  def when_i_click_on_the_consent
    click_on @parent.full_name
  end

  def and_i_click_invalidate_consent
    click_on "Mark as invalid"
  end

  def when_i_fill_in_the_notes
    fill_in "Notes", with: "Some notes."
  end

  def then_i_see_the_consent_has_been_invalidated
    expect(page).to have_content("Invalid")
    if @parent
      expect(page).to have_content(
        "Consent response from #{@parent.full_name} marked as invalid"
      )
    else
      expect(page).to have_content(
        "Consent response from #{@patient.full_name} marked as invalid"
      )
    end
  end

  def and_i_cant_mark_as_invalid
    expect(page).not_to have_content("Mark as invalid")
  end

  def when_i_click_back
    click_on "Back"
  end

  def and_i_am_not_able_to_record_a_vaccination
    expect(page).to have_content("No response")
    expect(page).not_to have_content("ready for their HPV vaccination?")
  end

  def and_self_consent_has_been_given_with_no_parent_notification
    @consent =
      create(
        :consent,
        :given,
        :self_consent,
        patient: @patient,
        programme: @programme
      )
    PatientStatusUpdater.call(patient: @patient.reload)
  end

  def when_the_patient_has_been_vaccinated_with_no_parent_notification
    @vaccination_record =
      create(
        :vaccination_record,
        patient: @patient,
        programme: @programme,
        session: @session,
        notify_parents: false
      )
  end

  def then_i_see_the_self_consent
    expect(page).to have_content("Child (Gillick competent)")
  end

  def when_i_click_on_the_self_consent
    click_on "Child (Gillick competent)"
  end

  def and_the_vaccination_record_is_updated_to_notify_parents_true
    expect(@vaccination_record.reload.notify_parents).to be true
  end

  def then_the_record_is_not_synced_to_the_imms_api
    @stubbed_post_request =
      stub_immunisations_api_post(uuid: @vaccination_record.uuid)

    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).not_to have_been_requested
  end

  def and_the_vaccination_record_is_synced_to_the_imms_api
    Sidekiq::Job.drain_all
    expect(@stubbed_post_request).to have_been_requested
  end
end
