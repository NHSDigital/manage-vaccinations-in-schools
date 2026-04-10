# frozen_string_literal: true

describe "Record already vaccinated" do
  scenario "HPV" do
    given_i_am_signed_in

    when_i_go_to_a_patient
    and_i_click_on_the_programme
    then_i_see_the_patient_page
    and_i_click_record_already_vaccinated
    and_i_click_back
    then_i_see_the_patient_page

    when_i_click_record_already_vaccinated
    and_i_choose_a_date
    and_i_choose_an_outcome
    then_i_see_the_confirmation_page

    when_i_confirm_the_details
    then_i_see_a_success_message

    when_i_go_to_a_patient
    and_i_click_on_the_programme
    then_i_see_that_the_status_is_vaccinated
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]

    team = create(:team, :with_one_nurse, programmes:)
    school = create(:school, :secondary, team:, programmes:)

    @patient = create(:patient, :consent_no_response, school:, programmes:)

    sign_in team.users.first
  end

  def when_i_go_to_a_patient
    visit patient_path(@patient)
  end

  def and_i_click_on_the_programme
    within(".app-secondary-navigation") { click_on "HPV" }
  end

  def then_i_see_the_patient_page
    expect(page).to have_content(@patient.full_name)
  end

  def and_i_click_record_already_vaccinated
    click_on "Record as already vaccinated"
  end

  def and_i_click_back
    click_on "Back"
  end

  alias_method :when_i_click_record_already_vaccinated,
               :and_i_click_record_already_vaccinated

  def and_i_choose_a_date
    fill_in "Day", with: "1"
    fill_in "Month", with: "1"
    fill_in "Year", with: "2020"
    click_on "Continue"
  end

  def and_i_choose_an_outcome
    # Vaccinated should already be selected
    click_on "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("OutcomeVaccinated")
  end

  def when_i_confirm_the_details
    click_on "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end

  def then_i_see_that_the_status_is_vaccinated
    expect(page).to have_content("HPVVaccinated")
  end
end
