# frozen_string_literal: true

describe "MMRV vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 10, 1)) { example.run } }

  scenario "administered at community clinic" do
    given_i_am_signed_in_as_a_nurse
    and_a_patient_has_consented_for_mmrv

    when_i_go_to_the_patients_tab
    then_i_should_consent_for_mmrv

    when_i_go_to_the_record_tab
    then_i_should_see_mmrv_vaccine_type

    when_i_go_to_the_patient
    then_i_see_the_vaccination_form

    when_i_begin_recording_the_vaccination_for_mmrv
    then_i_should_only_see_the_mmrv_batch_options

    when_i_choose_an_mmrv_batch_for_the_vaccine
    then_i_see_the_check_and_confirm_page_with_mmrv
    and_i_get_confirmation_after_recording
    and_i_should_see_a_triage_for_the_next_vaccination_dose

    when_i_go_to_the_activity_log
    then_i_see_the_right_entries

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  scenario "there is no more MMRV stock available" do
    given_i_am_signed_in_as_a_nurse
    and_a_patient_exists

    when_i_visit_the_patient_mmrv_tab
    and_i_start_a_new_consent_response
    and_i_get_consent_for_mmr
    then_i_see_the_check_and_confirm_page_with_mmr

    when_i_confirm_the_consent_response
    then_i_see_a_message_that_the_consent_is_successful

    when_i_click_on_the_patient
    and_i_begin_recording_the_vaccination_for_mmr
    then_i_should_only_see_the_mmr_batch_options
  end

  scenario "patient has MMRV consent, then consents for MMR" do
    given_i_am_signed_in_as_a_nurse
    and_a_patient_has_consented_for_mmrv

    when_i_visit_the_patient_mmrv_tab
    and_i_start_a_new_consent_response
    and_i_get_consent_for_mmr
    then_i_see_the_check_and_confirm_page_with_mmr

    when_i_confirm_the_consent_response
    then_i_see_a_message_that_the_consent_is_conflicting
  end

  def given_i_am_signed_in_as_a_nurse
    @programme = Programme.mmr
    @team = create(:team, :with_one_nurse, programmes: [@programme])

    @mmrv_vaccine = Vaccine.find_by!(brand: "ProQuad")
    @mmrv_batch =
      create(:batch, :not_expired, team: @team, vaccine: @mmrv_vaccine)

    @mmr_vaccine = Vaccine.find_by!(brand: "Priorix")
    @mmr_batch =
      create(:batch, :not_expired, team: @team, vaccine: @mmr_vaccine)

    sign_in @team.users.first
  end

  def and_a_patient_has_consented_for_mmrv
    location = @team.generic_clinic
    @session =
      create(:session, team: @team, programmes: [@programme], location:)
    @parent = create(:parent)
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session,
        parents: [@parent],
        date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month,
        programmes: [
          @programme.variant_for(
            disease_types: Programme::Variant::DISEASE_TYPES["mmrv"]
          )
        ]
      )
    PatientStatusUpdater.call(patient: @patient)
    @community_clinic = create(:community_clinic, team: @team)
  end

  def and_a_patient_exists
    location = @team.generic_clinic
    @session =
      create(:session, team: @team, programmes: [@programme], location:)
    @parent = create(:parent)
    @patient =
      create(
        :patient,
        :in_attendance,
        session: @session,
        parents: [@parent],
        date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month
      )

    @community_clinic = create(:community_clinic, team: @team)
  end

  def when_i_go_to_the_patients_tab
    visit session_patients_path(@session)
  end

  def then_i_should_consent_for_mmrv
    expect(page).to have_content("MMRVDue 1st dose")
  end

  def when_i_go_to_the_record_tab
    visit session_record_path(@session)
  end

  def then_i_should_see_mmrv_vaccine_type
    expect(page).to have_content("No preference for MMRV")
  end

  def when_i_go_to_the_patient
    click_link @patient.full_name
  end

  def when_i_visit_the_patient_mmrv_tab
    visit session_patient_programme_path(@session, @patient, @programme)
  end

  def when_i_go_to_the_without_gelatine_patient
    visit session_consent_path(@session)
    check "Consent given"
    click_on "Search"

    expect(page).not_to have_content(@without_gelatine_only_patient.full_name)
    expect(page).to have_content(@without_gelatine_patient.full_name)
    expect(page).to have_content(@with_gelatine_patient.full_name)

    @patient = @without_gelatine_patient

    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def when_i_go_to_the_with_gelatine_patient
    visit session_consent_path(@session)
    check "Consent given"
    click_on "Search"

    expect(page).not_to have_content(@without_gelatine_only_patient.full_name)
    expect(page).to have_content(@without_gelatine_patient.full_name)
    expect(page).to have_content(@with_gelatine_patient.full_name)

    @patient = @with_gelatine_patient

    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_the_vaccination_form
    expect(page).to have_content("Record MMRV vaccination")
    expect(page).to have_content(
      "Is #{@patient.given_name} ready for their MMRV vaccination?"
    )
  end

  def when_i_begin_recording_the_vaccination_for_mmrv
    expect(page).to have_content("Record MMRV vaccination")

    within all("form")[3] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      within all("fieldset")[2] do
        choose "Yes"
        choose "Left arm (upper position)"
      end

      click_button "Continue"
    end
  end

  def and_i_begin_recording_the_vaccination_for_mmr
    expect(page).to have_content("Record MMR vaccination")

    within all("form")[3] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      within all("fieldset")[2] do
        choose "Yes"
        choose "Left arm (upper position)"
      end

      click_button "Continue"
    end
  end

  def then_i_should_only_see_the_mmrv_batch_options
    expect(page).to have_content(@mmrv_vaccine.brand)
    expect(page).not_to have_content(@mmr_vaccine.brand)
    expect(page).to have_content(@mmrv_batch.number)
    expect(page).not_to have_content(@mmr_batch.number)
  end

  def then_i_should_only_see_the_mmr_batch_options
    expect(page).to have_content(@mmr_vaccine.brand)
    expect(page).not_to have_content(@mmrv_vaccine.brand)
    expect(page).to have_content(@mmr_batch.number)
    expect(page).not_to have_content(@mmrv_batch.number)
  end

  def when_i_choose_an_mmrv_batch_for_the_vaccine
    choose @mmrv_batch.number
    click_button "Continue"

    expect(page).to have_content("Where was the MMRV vaccination offered?")
    choose @community_clinic.name
    click_button "Continue"
  end

  def then_i_see_the_check_and_confirm_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("ProgrammeMMRV")
  end

  def and_i_get_confirmation_after_recording
    click_button "Confirm"
    expect(page).to have_content("Vaccination outcome recorded for MMR")
  end

  def when_i_go_to_the_activity_log
    click_on "Session activity and notes"
  end

  def then_i_see_the_right_entries
    expect(page).to have_content("Completed pre-screening checks")
    expect(page).to have_content("Vaccinated with ProQuad")
    expect(page).to have_content(
      "Triaged decision: Delay vaccination to a later date\n" \
        "MMR(V) 1 October 2024 at 12:00am\n" \
        "Next dose 29 October 2024 at 12:00am"
    )
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.new.perform
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.last.parent.email,
        subject: "Your child had their MMRV vaccination today",
        template: :vaccination_administered
      ).with_content_including(
        "MMRV vaccination",
        "ProQuad",
        "a raised, blotchy rash",
        "swollen glands around the cheeks, neck and jaw",
        "Your child still needs a 2nd dose of the MMRV vaccine"
      )
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_vaccination
    expect_sms_to(
      @patient.consents.last.parent.phone,
      :vaccination_administered
    )
  end

  def and_i_click_on_edit_vaccination_record
    click_on "Edit vaccination record"
  end

  def and_i_should_see_a_triage_for_the_next_vaccination_dose
    expect(page).to have_content("MMRV: Delay vaccination")
    expect(page).to have_content("Next dose 29 October 2024")
  end

  def then_i_should_see_a_triage_with_the_new_date_for_vaccination
    expect(page).to have_content("Next dose 05 November 2024")
  end

  def and_i_start_a_new_consent_response
    click_button "Record a new consent response"
  end

  def and_i_get_consent_for_mmr
    choose @parent.full_name
    click_button "Continue"

    # Details for parent or guardian: leave prepopulated details
    click_button "Continue"

    # How was the response given?
    choose "By phone"
    click_button "Continue"

    # Can you vaccinate patient with an MMRV vaccine?
    choose "No"
    click_button "Continue"

    # Do they agree to have MMR?
    choose "Yes, they agree"
    choose "Yes, they want their child to have a vaccine that does not contain gelatine"
    click_button "Continue"

    # No to all health questions
    3.times { |index| find_all(".nhsuk-fieldset")[index].choose "No" }

    click_button "Continue"
  end

  def then_i_see_the_check_and_confirm_page_with_mmrv
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("ProgrammeMMRV")
  end

  def then_i_see_the_check_and_confirm_page_with_mmr
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("ProgrammeMMR")
    expect(page).not_to have_content("ProgrammeMMRV")
  end

  def when_i_confirm_the_consent_response
    click_button "Confirm"
  end

  def then_i_see_a_message_that_the_consent_is_successful
    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
    expect(page).to have_content("Programme status\nMMRDue 1st dose")
  end

  def then_i_see_a_message_that_the_consent_is_conflicting
    expect(page).to have_content("Conflicting consent")
  end

  def when_i_click_on_the_patient
    click_on @patient.full_name, match: :first
  end
end
