# frozen_string_literal: true

describe "Record already vaccinated" do
  scenario "MMR" do
    given_i_am_signed_in

    when_i_go_to_a_patient
    and_i_click_on_the_programme
    then_i_see_the_patient_page

    when_i_click_record_first_dose_vaccinated
    and_i_choose_a_date_for_the_first_dose
    then_i_see_the_confirmation_page_for_the_first_dose

    when_i_confirm_the_details
    then_i_see_a_success_message

    when_i_go_to_a_patient
    and_i_click_on_the_programme
    then_i_see_that_the_status_is_not_yet_vaccinated

    when_i_click_record_second_dose_vaccinated
    and_i_choose_a_date_for_the_second_dose
    then_i_see_the_confirmation_page_for_the_second_dose

    when_i_confirm_the_details
    then_i_see_a_success_message

    when_i_go_to_a_patient
    and_i_click_on_the_programme
    then_i_see_that_the_status_is_vaccinated
  end

  def given_i_am_signed_in
    programmes = [Programme.mmr]

    team = create(:team, :with_one_nurse, programmes:)
    school = create(:gias_school, :secondary, team:, programmes:)

    @patient =
      create(
        :patient,
        :consent_no_response,
        school:,
        date_of_birth: 18.years.ago,
        programmes:
      )

    PatientStatusUpdater.call(patient: @patient)

    sign_in team.users.first
  end

  def when_i_go_to_a_patient
    visit patient_path(@patient)
  end

  def and_i_click_on_the_programme
    within(".app-secondary-navigation") { click_on "MMR(V)" }
  end

  def then_i_see_the_patient_page
    expect(page).to have_content(@patient.full_name)
  end

  def when_i_click_record_first_dose_vaccinated
    click_on "Record 1st dose as already given"
  end

  def when_i_click_record_second_dose_vaccinated
    click_on "Record 2nd dose as already given"
  end

  def and_i_click_back
    click_on "Back"
  end

  def and_i_choose_a_date_for_the_first_dose
    fill_in "Day", with: "1"
    fill_in "Month", with: "1"
    fill_in "Year", with: "2021"
    click_on "Continue"
  end

  def and_i_choose_a_date_for_the_second_dose
    fill_in "Day", with: "1"
    fill_in "Month", with: "1"
    fill_in "Year", with: "2022"
    click_on "Continue"
  end

  def then_i_see_the_confirmation_page_for_the_first_dose
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("OutcomeVaccinated")
    expect(page).to have_content("Dose number1st")
  end

  def then_i_see_the_confirmation_page_for_the_second_dose
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("OutcomeVaccinated")
    expect(page).to have_content("Dose number2nd")
  end

  def when_i_confirm_the_details
    click_on "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for MMR")
  end

  def then_i_see_that_the_status_is_not_yet_vaccinated
    expect(page).to have_content("MMRNeeds consent")
  end

  def then_i_see_that_the_status_is_vaccinated
    expect(page).to have_content("MMRVaccinated")
  end
end
