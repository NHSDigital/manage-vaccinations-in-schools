# frozen_string_literal: true

describe "Td/IPV" do
  around { |example| travel_to(Date.new(2025, 7, 1)) { example.run } }

  scenario "record a patient as already vaccinated outside the school session" do
    given_a_td_ipv_programme_with_a_session(clinic: false)
    and_a_patient_is_in_the_session
    and_the_patient_doesnt_need_triage

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_vaccinated
    when_i_click_back
    then_i_see_the_patient_session_page

    when_i_click_record_as_already_vaccinated
    then_i_see_the_date_page

    when_i_fill_in_the_date_and_continue
    and_i_confirm_the_details
    then_i_see_the_patient_is_already_vaccinated
    and_i_see_that_the_location_is_unknown
    and_the_consent_requests_are_sent
    then_the_parent_doesnt_receive_a_consent_request
  end

  scenario "record a patient as already vaccinated outside the clinic session" do
    given_a_td_ipv_programme_with_a_session(clinic: true)
    and_a_patient_is_in_the_session
    and_the_patient_doesnt_need_triage

    when_i_go_the_session
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent

    when_i_click_record_as_already_vaccinated
    then_i_see_the_date_page

    when_i_fill_in_the_date_and_continue

    and_i_confirm_the_details
    then_i_see_the_patient_is_already_vaccinated
    and_the_consent_requests_are_sent
    then_the_parent_doesnt_receive_a_consent_request
  end

  scenario "record a patient needing triage as already vaccinated outside the school session" do
    given_a_td_ipv_programme_with_a_session(clinic: false)
    and_a_patient_is_in_the_session
    and_the_patient_needs_triage

    when_i_go_the_session
    then_i_see_one_patient_needing_triage
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_triage

    when_i_click_record_as_already_vaccinated
    then_i_see_the_date_page

    when_i_fill_in_the_date_and_continue
    and_i_confirm_the_details
    then_i_see_the_patient_is_already_vaccinated
    and_i_see_that_the_location_is_unknown
  end

  scenario "can't record as already vaccinated as a medical secretary" do
    given_a_td_ipv_programme_with_a_session(clinic: false)
    and_a_patient_is_in_the_session
    and_the_patient_doesnt_need_triage

    when_i_go_the_session_as_an_admin
    then_i_see_one_patient_needing_consent
    and_i_click_on_the_patient
    then_i_see_the_patient_needs_consent
    and_i_cannot_record_the_patient_as_already_vaccinated
  end

  def given_a_td_ipv_programme_with_a_session(clinic:)
    @programme = Programme.td_ipv
    programmes = [@programme]

    team = create(:team, programmes:)
    @nurse = create(:nurse, teams: [team])

    location =
      if clinic
        create(:generic_clinic, team:)
      else
        create(:school, :secondary, urn: 123_456, team:)
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

  def and_a_patient_is_in_the_session
    @patient = create(:patient, session: @session)
  end

  def and_the_patient_doesnt_need_triage
    PatientStatusUpdater.call(patient: @patient.reload)
  end

  def and_the_patient_needs_triage
    create(
      :consent,
      :given,
      :needing_triage,
      patient: @patient,
      programme: @programme
    )
    PatientStatusUpdater.call(patient: @patient.reload)
  end

  def when_i_go_the_session
    sign_in @nurse
    visit dashboard_path
    click_on "Sessions", match: :first
    choose "Scheduled"
    click_on "Update results"
    click_on @session.location.name
  end

  def when_i_go_the_session_as_an_admin
    sign_in @nurse, role: :medical_secretary
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

  def then_i_see_one_patient_needing_triage
    within(".app-secondary-navigation") { click_on "Children" }

    choose "Needs triage"
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
  end

  def and_i_click_on_the_patient
    click_on @patient.full_name
  end

  def then_i_see_the_patient_needs_consent
    expect(page).to have_content("No contact details")
  end

  def then_i_see_the_patient_needs_triage
    expect(page).to have_content("Needs triage")
  end

  def when_i_click_record_as_already_vaccinated
    click_on "Record as already vaccinated"
  end

  def when_i_click_back
    click_on "Back"
  end

  def then_i_see_the_date_page
    expect(page).to have_content("When was the Td/IPV vaccination given?")
  end

  def when_i_fill_in_the_date_and_continue
    @vaccination_date = 6.months.ago.to_date
    fill_in "Day", with: @vaccination_date.day
    fill_in "Month", with: @vaccination_date.month
    fill_in "Year", with: @vaccination_date.year
    fill_in "Hour", with: "12"
    fill_in "Minute", with: "00"
    click_on "Continue"
  end

  def then_i_see_the_location_page
    expect(page).to have_content("Where was the Td/IPV vaccination offered?")
  end

  def when_i_fill_in_the_location_and_continue
    choose "Waterloo Hospital"
    click_on "Continue"
  end

  def and_i_confirm_the_details
    click_on "Confirm"
  end

  def then_i_see_the_patient_session_page
    expect(page).to have_content("Session activity and notes")
  end

  def then_i_see_the_patient_is_already_vaccinated
    expect(page).to have_content("Vaccination outcome recorded for Td/IPV")
  end

  def and_i_see_that_the_location_is_unknown
    expect(page).to have_content("LocationUnknown")
  end

  def and_i_cannot_record_the_patient_as_already_vaccinated
    expect(page).not_to have_content("Record as already vaccinated")
  end

  def and_the_consent_requests_are_sent
    EnqueueSchoolConsentRequestsJob.perform_now
    perform_enqueued_jobs
  end

  def then_the_parent_doesnt_receive_a_consent_request
    expect(EmailDeliveryJob.deliveries).to be_empty
  end
end
