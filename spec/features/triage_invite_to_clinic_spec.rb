# frozen_string_literal: true

describe "Triage" do
  around { |example| travel_to(Date.new(2025, 7, 1)) { example.run } }

  scenario "invite to clinic consent given no triage needed" do
    given_a_programme_with_a_running_session
    and_i_am_signed_in
    and_a_patient_who_doesnt_need_triage_exists

    when_i_go_to_the_patients_tab

    when_i_click_on_a_patient
    and_i_click_on_update_triage_outcome
    and_i_enter_a_note_and_invite_to_clinic
    then_i_see_an_alert_saying_the_record_was_saved
    and_a_vaccination_at_clinic_email_is_sent_to_the_parent

    when_i_filter_by_invited_to_clinic
    then_i_see_the_patient

    when_i_access_the_vaccinate_later_page
    then_i_see_the_patient

    when_i_view_the_child_record
    then_they_should_have_the_status_banner_invited_to_clinic
    and_i_am_not_able_to_record_a_vaccination
    and_i_am_able_to_update_the_triage
  end

  scenario "invite to clinic consent given and needs triage" do
    given_a_programme_with_a_running_session
    and_i_am_signed_in
    and_a_patient_who_needs_triage_exists

    when_i_go_to_the_patients_tab

    when_i_click_on_a_patient
    and_i_enter_a_note_and_invite_to_clinic
    then_i_see_an_alert_saying_the_record_was_saved
    and_a_vaccination_at_clinic_email_is_sent_to_the_parent

    when_i_filter_by_invited_to_clinic
    then_i_see_the_patient

    when_i_access_the_vaccinate_later_page
    then_i_see_the_patient

    when_i_view_the_child_record
    then_they_should_have_the_status_banner_invited_to_clinic
    and_i_am_not_able_to_record_a_vaccination
    and_i_am_able_to_update_the_triage
  end

  scenario "invite to clinic sends LPT-specific email for teams with ODS code RT5" do
    given_a_programme_with_a_running_session_for_team(ods_code: "RT5")
    and_i_am_signed_in
    and_a_patient_who_needs_triage_exists

    when_i_go_to_the_patients_tab
    when_i_click_on_a_patient
    and_i_enter_a_note_and_invite_to_clinic
    then_i_see_an_alert_saying_the_record_was_saved
    and_a_vaccination_at_clinic_rt5_email_is_sent_to_the_parent
  end

  scenario "invite to clinic sends CWPT-specific email for teams with ODS code RYG" do
    given_a_programme_with_a_running_session_for_team(ods_code: "RYG")
    and_i_am_signed_in
    and_a_patient_who_needs_triage_exists

    when_i_go_to_the_patients_tab
    when_i_click_on_a_patient
    and_i_enter_a_note_and_invite_to_clinic
    then_i_see_an_alert_saying_the_record_was_saved
    and_a_vaccination_at_clinic_ryg_email_is_sent_to_the_parent
  end

  def given_a_programme_with_a_running_session
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)
    @school = create(:gias_school, team: @team)

    @session = create(:session, team: @team, programmes:, location: @school)
  end

  def given_a_programme_with_a_running_session_for_team(ods_code:)
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:, ods_code:)
    @school = create(:gias_school, team: @team)

    @session = create(:session, team: @team, programmes:, location: @school)
  end

  def and_a_patient_who_needs_triage_exists
    @patient =
      create(
        :patient,
        :consent_given_triage_needed,
        :in_attendance,
        session: @session
      )
  end

  def and_a_patient_who_doesnt_need_triage_exists
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_go_to_the_patients_tab
    visit session_patients_path(@session)
  end

  def when_i_click_on_a_patient
    click_link @patient.full_name
  end

  def and_i_click_on_update_triage_outcome
    click_on "Update triage outcome"
  end

  def and_i_enter_a_note_and_invite_to_clinic
    fill_in "Triage notes (optional)", with: "Invite to clinic"
    choose "No, invite to clinic"
    and_i_save_triage
  end

  def and_i_choose_to_delay_vaccination
    choose "No, delay vaccination"
  end

  def and_i_enter_a_date_beyond_the_current_academic_year
    fill_in_date(Date.new(2025, 9, 1))
  end

  def when_i_enter_valid_date
    fill_in_date(1.week.from_now)
  end

  def and_i_save_triage
    click_button "Save triage"
  end

  def then_i_see_an_error_that_date_cannot_be_beyond_academic_year
    expect(page).to have_content(
      "The vaccination date cannot go beyond 31 August 2025"
    )
  end

  def then_i_see_an_alert_saying_the_record_was_saved
    expect(page).to have_alert("Success", text: "Triage outcome updated")
  end

  def and_a_vaccination_at_clinic_email_is_sent_to_the_parent
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.first.parent.email,
        template: :triage_vaccination_at_clinic
      ).with_content_including(
        "vaccinated in a clinic",
        "contact us using the details below"
      )
    )
  end

  def and_a_vaccination_at_clinic_rt5_email_is_sent_to_the_parent
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.first.parent.email,
        template: :triage_vaccination_at_clinic_rt5
      ).with_content_including(
        "invitation to book a clinic appointment",
        "2 to 3 working days"
      )
    )
  end

  def and_a_vaccination_at_clinic_ryg_email_is_sent_to_the_parent
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.first.parent.email,
        template: :triage_vaccination_at_clinic_ryg
      ).with_content_including("vaccinated in a clinic", "swiftqueue.co.uk")
    )
  end

  def when_i_filter_by_invited_to_clinic
    within(".nhsuk-breadcrumb") { click_on "Children in session" }
    choose "Needs triage"
    click_on "Update results"
  end

  def then_i_see_the_patient
    expect(page).to have_content(@patient.full_name)
  end

  def when_i_access_the_vaccinate_later_page
    within(".app-secondary-navigation") { click_on "Children" }
    choose "Needs triage", match: :first
    click_on "Update results"
  end

  def when_i_view_the_child_record
    click_link @patient.full_name
  end

  def then_they_should_have_the_status_banner_delay_vaccination
    expect(page).to have_content("Delay vaccination")
  end

  def then_they_should_have_the_status_banner_invited_to_clinic
    expect(page).to have_content("Invite to clinic")
  end

  def and_i_am_not_able_to_record_a_vaccination
    expect(page).not_to have_content("ready for their HPV vaccination?")
  end

  def and_i_am_able_to_update_the_triage
    expect(page).to have_content("Update triage outcome")
  end

  def fill_in_date(date)
    fill_in "Day", with: date.day
    fill_in "Month", with: date.month
    fill_in "Year", with: date.year
  end
end
