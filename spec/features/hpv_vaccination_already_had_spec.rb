# frozen_string_literal: true

describe "HPV vaccination" do
  scenario "Already had" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_record_that_the_patient_wasnt_vaccinated
    when_i_click_back
    then_i_see_the_patient_session_page

    and_i_record_that_the_patient_wasnt_vaccinated
    and_i_select_the_reason_why
    then_i_see_the_confirmation_page

    when_i_click_change_outcome
    and_i_select_the_reason_why
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
    and_the_disease_types_are_set_on_the_record
    and_i_no_longer_see_the_patient_in_the_record_tab

    when_i_go_to_the_patient
    then_i_see_that_the_status_is_vaccinated

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_saying_the_vaccination_didnt_happen
    and_a_text_is_sent_saying_the_vaccination_didnt_happen
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    team = create(:team, :with_one_nurse, programmes:)
    location = create(:school, team:)
    @batch = create(:batch, team:, vaccine: programmes.first.vaccines.first)
    @session = create(:session, team:, programmes:, location:)
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )

    sign_in team.users.first
  end

  def when_i_go_to_a_patient_that_is_safe_to_vaccinate
    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def and_i_record_that_the_patient_wasnt_vaccinated
    within all("section")[0] do
      check "I have checked that the above statements are true"
    end

    within all("section")[1] do
      choose "No"
      click_button "Continue"
    end
  end

  def and_i_select_the_reason_why
    choose "They have already had the vaccine"
    click_button "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Vaccination was not given")
    expect(page).to have_content("Child#{@patient.full_name}")
    expect(page).to have_content("OutcomeAlready had")
  end

  def when_i_click_change_outcome
    click_on "Change outcome"
  end

  def when_i_confirm_the_details
    click_button "Confirm"
  end

  def when_i_click_back
    click_on "Back"
  end

  def then_i_see_the_patient_session_page
    expect(page).to have_content("Session activity and notes")
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end

  def and_the_disease_types_are_set_on_the_record
    expect(VaccinationRecord.last.disease_types).to contain_exactly(
      "human_papillomavirus"
    )
  end

  def and_i_no_longer_see_the_patient_in_the_record_tab
    click_on "Record vaccinations"
    expect(page).to have_content("No children matching search criteria found")
  end

  def when_i_go_to_the_patient
    within(".app-secondary-navigation") { click_on "Children" }
    click_on @patient.full_name
  end

  def then_i_see_that_the_status_is_vaccinated
    expect(page).to have_content("Vaccinated")
    expect(page).to have_content("Already had the vaccine")
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.perform_now
  end

  def then_an_email_is_sent_saying_the_vaccination_didnt_happen
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.last.parent.email,
        template: :vaccination_not_administered
      ).with_content_including("did not have their")
    )
  end

  def and_a_text_is_sent_saying_the_vaccination_didnt_happen
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @patient.consents.last.parent.phone,
        template: :vaccination_not_administered
      ).with_content_including(
        "did not have their",
        "contact the local health team"
      )
    )
  end
end
