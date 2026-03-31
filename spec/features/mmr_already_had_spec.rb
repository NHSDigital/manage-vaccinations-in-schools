# frozen_string_literal: true

describe "MMR/MMRV" do
  around { |example| travel_to(Date.new(2025, 7, 1)) { example.run } }

  scenario "record a patient born after January 2020 as already had their 1st MMR dose outside the school session" do
    given_an_mmr_programme_with_a_session
    and_a_patient_is_in_the_session_born_after_january_2020
    and_the_patient_doesnt_need_triage
    and_the_patient_has_not_had_a_first_dose

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_had_first_dose
    when_i_click_back
    then_i_see_the_patient_session_page

    when_i_click_record_as_already_had_first_dose
    then_i_see_the_did_you_have_mmr_or_mmrv_page

    when_i_choose_mmr_and_continue
    then_i_see_the_mmr_date_page

    when_i_fill_in_the_date_and_time_and_continue
    then_i_see_the_confirmation_page
    and_the_confirmation_summary_is_not_displayed_as_a_warning

    when_i_confirm_the_details
    then_i_see_the_patient_is_already_vaccinated
    and_i_see_that_the_vaccinator_is_unknown
    and_i_see_that_the_location_is_unknown
    and_i_see_that_the_reporter_is_set
    and_i_see_that_there_are_no_vaccine_batch_details
    expect(page).to have_content("LocationUnknown")
    and_had_been_vaccinated_with_mmr
    and_the_dose_number_is_first
    and_the_consent_requests_are_sent
    then_the_parent_doesnt_receive_a_consent_request

    when_the_status_updater_runs
    and_i_navigate_to_the_patient_record
    and_i_click_on_the_mmr_programme
    then_i_see_that_the_vaccination_record_has_outcome_vaccinated
    and_i_see_a_historical_vaccination_log_entry
    and_it_includes_the_mmr_programme_and_both_reported_and_performed_at_dates
  end

  scenario "record a patient as already had their 1st MMR dose and then edit dates" do
    given_an_mmr_programme_with_a_session
    and_a_patient_is_in_the_session_born_after_january_2020
    and_the_patient_doesnt_need_triage
    and_the_patient_has_not_had_a_first_dose

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_had_first_dose
    then_i_see_the_did_you_have_mmr_or_mmrv_page

    when_i_choose_mmr_and_continue
    then_i_see_the_mmr_date_page

    when_i_fill_in_the_date_and_time_and_continue
    then_i_see_the_confirmation_page

    when_i_click_link_to_change_the_date
    then_i_see_the_mmr_date_page
    when_i_change_the_date_and_continue
    then_i_see_the_confirmation_page
    and_i_see_the_updated_date_in_the_summary
  end

  scenario "record a patient born before January 2020 as already had their 1st MMR dose outside the school session" do
    given_an_mmr_programme_with_a_session
    and_a_patient_is_in_the_session_born_before_january_2020
    and_the_patient_doesnt_need_triage
    and_the_patient_has_not_had_a_first_dose

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_had_first_dose
    then_i_see_the_mmr_date_instead_of_the_mmr_or_mmrv_page
  end

  scenario "parents are notified when their child's prior vaccination is added to the record" do
    given_an_mmr_programme_with_a_session
    and_a_patient_with_a_consenting_parent_is_in_the_session
    and_the_patients_prior_vaccination_is_recorded

    when_the_status_updater_runs

    when_the_prior_vaccination_notification_is_sent
    then_the_parent_receives_a_vaccination_already_had_email
    and_the_parent_receives_a_vaccination_already_had_sms
  end

  scenario "record a patient born after January 2020 as already had their 2nd MMRV dose outside the school session" do
    given_an_mmr_programme_with_a_session
    and_a_patient_is_in_the_session_born_after_january_2020
    and_the_patient_doesnt_need_triage
    and_the_patient_already_has_first_dose

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_had_second_dose
    then_i_see_the_did_you_have_mmr_or_mmrv_page

    when_i_choose_mmrv_and_continue
    then_i_see_the_mmrv_date_page

    when_i_fill_in_the_date_and_continue
    then_i_see_the_confirmation_page
    and_the_confirmation_summary_is_not_displayed_as_a_warning

    when_i_confirm_the_details
    then_i_see_the_patient_is_already_vaccinated
    and_i_see_that_the_vaccinator_is_unknown
    and_i_see_that_the_location_is_unknown
    and_i_see_that_the_reporter_is_set
    and_i_see_that_there_are_no_vaccine_batch_details
    and_had_been_vaccinated_with_mmrv
    and_the_dose_number_is_second
    and_the_consent_requests_are_sent
    then_the_parent_doesnt_receive_a_consent_request

    when_the_status_updater_runs
    and_i_navigate_to_the_patient_record
    and_i_click_on_the_mmr_programme
    then_i_see_that_the_vaccination_record_has_outcome_vaccinated
    and_i_see_a_historical_vaccination_log_entry
    and_it_includes_the_mmrv_programme_and_both_reported_and_performed_at_dates
  end

  def given_an_mmr_programme_with_a_session(clinic: false)
    @programme = Programme.mmr
    programmes = [@programme]

    team = create(:team, programmes:)
    @nurse = create(:nurse, teams: [team])

    location =
      if clinic
        create(:generic_clinic, team:)
      else
        create(:school, urn: 123_456, team:)
      end

    create(:community_clinic, name: "Waterloo Hospital", team:)

    @session =
      create(
        :session,
        date: 1.week.from_now.to_date,
        team:,
        programmes:,
        location:
      )
  end

  def and_a_patient_is_in_the_session_born_after_january_2020
    @patient =
      create(
        :patient,
        session: @session,
        date_of_birth: Date.new(2020, 1, 1),
        parents: [create(:parent)]
      )
  end

  def and_a_patient_is_in_the_session_born_before_january_2020
    @patient =
      create(
        :patient,
        session: @session,
        date_of_birth: Date.new(2019, 12, 31),
        parents: [create(:parent)]
      )
  end

  def and_the_patient_doesnt_need_triage
    PatientStatusUpdater.call(patient: @patient.reload)
  end

  def and_the_patient_already_has_first_dose
    programme_status =
      @patient.programme_status(@programme, academic_year: AcademicYear.current)
    programme_status.dose_sequence = 2
    programme_status.save!
  end

  def and_the_patient_has_not_had_a_first_dose
    programme_status =
      @patient.programme_status(@programme, academic_year: AcademicYear.current)
    programme_status.dose_sequence = 1
    programme_status.save!
  end

  def when_i_go_the_session
    sign_in @nurse
    visit dashboard_path
    click_on "Sessions", match: :first
    choose "Scheduled"
    click_on "Update results"
    click_on @session.location.name
  end

  def then_i_see_one_patient_needing_consent
    within(".app-secondary-navigation") { click_on "Children" }

    choose "Needs consent"
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def and_i_click_on_the_patient
    click_on @patient.full_name
  end

  def then_i_see_the_patient_needs_consent
    expect(page).to have_content("No response")
  end

  def when_i_click_record_as_already_vaccinated
    click_on "Record as already vaccinated"
  end

  def when_i_click_record_as_already_had_first_dose
    click_on "Record 1st dose as already given"
  end

  def when_i_click_record_as_already_had_second_dose
    click_on "Record 2nd dose as already given"
  end

  def when_i_click_back
    click_on "Back"
  end

  def then_i_see_the_did_you_have_mmr_or_mmrv_page
    expect(page).to have_content(
      "Was #{@patient.given_name} vaccinated with the MMRV vaccine?"
    )
  end

  def when_i_choose_mmr_and_continue
    choose "No, they got the MMR vaccine"
    click_on "Continue"
  end

  def when_i_choose_mmrv_and_continue
    choose "Yes, they got the MMRV vaccine"
    click_on "Continue"
  end

  def then_i_see_the_mmr_date_page
    expect(page).to have_content("When was the MMR vaccination given?")
  end

  def then_i_see_the_mmrv_date_page
    expect(page).to have_content("When was the MMRV vaccination given?")
  end

  def then_i_see_the_mmr_date_instead_of_the_mmr_or_mmrv_page
    expect(page).to have_content("When was the MMR vaccination given?")
  end

  def when_i_fill_in_the_date_and_time_and_continue
    @vaccination_date = 6.months.ago.to_date
    fill_in "Day", with: @vaccination_date.day
    fill_in "Month", with: @vaccination_date.month
    fill_in "Year", with: @vaccination_date.year
    fill_in "Hour", with: "12"
    fill_in "Minute", with: "30"
    click_on "Continue"
  end

  def when_i_fill_in_the_date_and_continue
    @vaccination_date = 6.months.ago.to_date
    fill_in "Day", with: @vaccination_date.day
    fill_in "Month", with: @vaccination_date.month
    fill_in "Year", with: @vaccination_date.year
    click_on "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
  end
  alias_method :then_i_see_the_confirmation_page_instead_of_the_mmrv_page,
               :then_i_see_the_confirmation_page

  def and_the_confirmation_summary_is_not_displayed_as_a_warning
    expect(page).to have_css("div.nhsuk-card")
    expect(page).not_to have_css("div.nhsuk-card--warning")
  end

  def when_i_confirm_the_details
    click_on "Confirm"
  end

  def then_i_see_the_patient_session_page
    expect(page).to have_content("Session activity and notes")
  end

  def then_i_see_the_patient_is_already_vaccinated
    expect(page).to have_content("Vaccination outcome recorded for MMR")
    expect(page).to have_content("OutcomeVaccinated")
  end

  def and_i_see_that_the_location_is_unknown
    expect(page).to have_content("LocationUnknown")
  end

  def and_i_see_that_the_vaccinator_is_unknown
    expect(page).to have_content("VaccinatorUnknown")
  end

  def and_i_see_that_the_reporter_is_set
    expect(page).to have_content("Reported by#{@nurse.full_name}")
  end

  def and_i_see_that_there_are_no_vaccine_batch_details
    expect(page).not_to have_content("Batch number")
    expect(page).not_to have_content("Batch expiry date")
    expect(page).not_to have_content("Site")
  end

  def and_had_been_vaccinated_with_mmr
    vaccination_record = @patient.vaccination_records.last
    expect(vaccination_record.programme_type).to eq("mmr")
    expect(vaccination_record.disease_types).to eq(
      Programme::Variant::DISEASE_TYPES["mmr"]
    )
    expect(vaccination_record.performed_at.to_date).to eq(@vaccination_date)
  end

  def and_had_been_vaccinated_with_mmrv
    vaccination_record = @patient.vaccination_records.last
    expect(vaccination_record.programme_type).to eq("mmr")
    expect(vaccination_record.disease_types).to eq(
      Programme::Variant::DISEASE_TYPES["mmrv"]
    )
    expect(vaccination_record.performed_at.to_date).to eq(@vaccination_date)
  end

  def and_the_dose_number_is_first
    expect(page).to have_content("Dose number1st")
    vaccination_record = @patient.vaccination_records.last
    expect(vaccination_record.dose_sequence).to be(1)
  end

  def and_the_dose_number_is_second
    expect(page).to have_content("Dose number2nd")
    vaccination_record = @patient.vaccination_records.last
    expect(vaccination_record.dose_sequence).to be(2)
  end

  def and_the_performed_at_date_and_time_are_set
    expect(page).to have_content(
      "Date#{@vaccination_date.strftime("%-d %B %Y")}"
    )
    expect(page).to have_content("Time12:30")
  end

  def and_the_performed_at_date_only_is_set
    expect(page).to have_content(
      "Date#{@vaccination_date.strftime("%-d %B %Y")}"
    )
  end

  def and_the_consent_requests_are_sent
    EnqueueSchoolConsentRequestsJob.perform_now
    perform_enqueued_jobs
  end

  def then_the_parent_doesnt_receive_a_consent_request
    expect(EmailDeliveryJob.deliveries).to be_empty
  end

  def when_i_click_link_to_change_the_date
    within(".nhsuk-summary-list__actions[contains('Change date')]") do
      click_on "Change"
    end
  end

  def when_i_change_the_date_and_continue
    @vaccination_date += 1.day

    fill_in "Day", with: @vaccination_date.day
    fill_in "Month", with: @vaccination_date.month
    fill_in "Year", with: @vaccination_date.year

    click_on "Continue"
  end

  def and_i_see_the_updated_date_in_the_summary
    expect(page).to have_content(
      "Date#{@vaccination_date.strftime("%-d %B %Y")}"
    )
  end

  def when_the_status_updater_runs
    PatientStatusUpdaterJob.perform_inline(@patient.id)
  end

  def and_i_navigate_to_the_patient_record
    visit patient_path(@patient)
  end

  def and_i_click_on_the_mmr_programme
    within(".app-secondary-navigation") { click_on "MMR" }
  end

  def then_i_see_that_the_vaccination_record_has_outcome_vaccinated
    expect(page).to have_content(
      "Vaccination date #{@vaccination_date.strftime("%-d %B %Y")}"
    )
    expect(page).to have_content("Programme MMR")
    expect(page).to have_content("Source Manual report")
    expect(page).to have_content("Outcome Vaccinated")
  end

  def and_i_see_a_historical_vaccination_log_entry
    expect(page).to have_content("Vaccination record added manually")
  end

  def and_it_includes_the_mmr_programme_and_both_reported_and_performed_at_dates
    expect(page).to have_content(
      "Vaccination record added manually\n" \
        "MMR Record added to Mavis 1 July 2025 at 12:00am · " \
        "Vaccination given #{@vaccination_date.strftime("%-d %B %Y")}"
    )
  end

  def and_it_includes_the_mmrv_programme_and_both_reported_and_performed_at_dates
    expect(page).to have_content(
      "Vaccination record added manually\n" \
        "MMRV Record added to Mavis 1 July 2025 at 12:00am · " \
        "Vaccination given #{@vaccination_date.strftime("%-d %B %Y")}"
    )
  end

  def and_a_patient_with_a_consenting_parent_is_in_the_session
    @parent = create(:parent, phone_receive_updates: true)
    @patient =
      create(
        :patient,
        session: @session,
        date_of_birth: Date.new(2020, 1, 1),
        parents: [@parent]
      )
    create(
      :consent,
      :given,
      patient: @patient,
      programme: @programme,
      parent: @parent,
      team: @session.team
    )
  end

  def and_the_patients_prior_vaccination_is_recorded
    @vaccination_record =
      create(
        :vaccination_record,
        :already_had,
        :sourced_from_manual_report,
        patient: @patient,
        programme: @programme,
        session: @session,
        performed_at: 6.months.ago
      )
  end

  def when_the_prior_vaccination_notification_is_sent
    AlreadyHadNotificationSender.call(vaccination_record: @vaccination_record)
  end

  def then_the_parent_receives_a_vaccination_already_had_email
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template: :vaccination_already_had
      ).with_content_including(
        "vaccinated at another location",
        "cancelling their vaccination appointment"
      )
    )
  end

  def and_the_parent_receives_a_vaccination_already_had_sms
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :vaccination_already_had
      ).with_content_including("at school", "another location")
    )
  end
end
