# frozen_string_literal: true

describe "HPV vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  scenario "Administered at a clinic" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_record_that_the_patient_has_been_vaccinated
    and_i_select_the_batch
    and_i_select_a_location
    then_i_see_the_confirmation_page

    when_i_click_change_location
    and_i_select_a_location
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message
    and_i_no_longer_see_the_patient_in_the_record_tab

    when_i_go_to_the_patient
    then_i_see_that_the_status_is_vaccinated

    when_vaccination_confirmations_are_sent
    then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    and_a_text_is_sent_to_the_parent_confirming_the_vaccination
  end

  def given_i_am_signed_in
    programme = Programme.hpv
    team = create(:team, :with_one_nurse, programmes: [programme])
    location = create(:generic_clinic, team:)

    @community_clinic = create(:community_clinic, team:)

    programme.vaccines.discontinued.each do |vaccine|
      create(:batch, team:, vaccine:)
    end

    active_vaccine = programme.vaccines.active.first
    @active_batch = create(:batch, :not_expired, team:, vaccine: active_vaccine)

    @session = create(:session, team:, programmes: [programme], location:)
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

  def and_i_record_that_the_patient_has_been_vaccinated
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

  def and_i_select_the_batch
    choose @active_batch.number
    click_button "Continue"
  end

  def and_i_select_a_location
    choose @community_clinic.name
    click_button "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("Child#{@patient.full_name}")
    expect(page).to have_content("Batch number#{@active_batch.number}")
    expect(page).to have_content("MethodIntramuscular")
    expect(page).to have_content("SiteLeft arm")
    expect(page).to have_content("OutcomeVaccinated")
  end

  def when_i_click_change_location
    click_on "Change location"
  end

  def when_i_confirm_the_details
    click_button "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end

  def and_i_no_longer_see_the_patient_in_the_record_tab
    click_on "Record vaccinations"
    expect(page).to have_content("No children matching search criteria found")
  end

  def when_i_go_to_the_patient
    within(".app-secondary-navigation") { click_on "Children" }
    click_on @patient.full_name, match: :first
  end

  def then_i_see_that_the_status_is_vaccinated
    expect(page).to have_content("Vaccinated")
  end

  def when_vaccination_confirmations_are_sent
    SendVaccinationConfirmationsJob.perform_now
  end

  def then_an_email_is_sent_to_the_parent_confirming_the_vaccination
    expect_email_to(
      @patient.consents.last.parent.email,
      :vaccination_administered
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_the_vaccination
    expect_sms_to(
      @patient.consents.last.parent.phone,
      :vaccination_administered
    )
  end
end
