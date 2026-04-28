# frozen_string_literal: true

describe "HPV vaccination" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Delayed (unwell)" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_record_that_the_patient_was_unwell
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
    and_i_still_see_the_patient_in_the_record_tab

    when_i_go_to_the_patient
    then_i_see_that_the_status_is_delayed
    and_i_can_record_a_second_vaccination

    when_i_go_to_the_children_tab
    then_i_see_the_patient_has_no_outcome_yet

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_delay
    and_a_text_is_sent_to_the_parent_confirming_the_delay
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)

    location = create(:gias_school, team: @team)
    @batch =
      create(:batch, team: @team, vaccine: programmes.first.vaccines.first)

    @session = create(:session, team: @team, programmes:, location:)
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )

    sign_in @team.users.first
  end

  def when_i_go_to_a_patient_that_is_safe_to_vaccinate
    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def and_i_record_that_the_patient_was_unwell
    within all("form")[3] do
      within all("fieldset")[2] do
        choose "No"
      end

      click_button "Continue"
    end

    choose "They were not well enough"
    click_button "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Child#{@patient.full_name}")
    expect(page).to have_content("OutcomeUnwell")
  end

  def when_i_confirm_the_details
    click_button "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end

  def and_i_still_see_the_patient_in_the_record_tab
    click_on "Record vaccinations"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patient.full_name)
  end

  def when_i_go_to_the_patient
    click_link @patient.full_name, match: :first
  end

  def then_i_see_that_the_status_is_delayed
    expect(page).to have_content("HPV: Unable to vaccinate")
    expect(page).not_to have_content("You still need to record an outcome")
  end

  def and_i_can_record_a_second_vaccination
    expect(page).to have_content("ready for their HPV vaccination?")
  end

  def when_i_go_to_the_children_tab
    click_on @session.location.name
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def then_i_see_the_patient_has_no_outcome_yet
    expect(page).to have_content(
      "Programme status\nHPVUnable to vaccinateChild unwell"
    )
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.new.perform
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_delay
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @patient.consents.last.parent.email,
        template: :vaccination_not_administered
      ).with_content_including("catch-up clinic")
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_delay
    expect_sms_to(
      @patient.consents.last.parent.phone,
      :vaccination_not_administered
    )
  end
end
