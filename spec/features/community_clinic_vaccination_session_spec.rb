# frozen_string_literal: true

describe "Community clinic vaccination session" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "patient attended but refused" do
    given_i_am_signed_in_as_a_nurse
    and_a_patient_is_ready_for_vaccination_in_a_community_clinic
    when_i_record_a_non_administered_vaccination_with_reason
    and_i_select_a_location
    then_i_see_the_confirmation_page
    when_i_confirm_the_details
    then_i_see_a_success_message
  end

  def given_i_am_signed_in_as_a_nurse
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    sign_in @team.users.first
  end

  def and_a_patient_is_ready_for_vaccination_in_a_community_clinic
    location = @team.generic_clinic
    @session =
      create(:session, team: @team, programmes: [@programme], location:)
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )
    @community_clinic = create(:community_clinic, team: @team)
  end

  def when_i_record_a_non_administered_vaccination_with_reason
    visit session_record_path(@session)
    click_link @patient.full_name

    within all("form")[2] do
      within all("fieldset")[2] do
        choose "No"
      end
      click_button "Continue"
    end

    choose "They refused"
    click_button "Continue"
  end

  def and_i_select_a_location
    choose @community_clinic.name
    click_button "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("OutcomeRefused")
  end

  def when_i_confirm_the_details
    click_button "Confirm"
  end

  def then_i_see_a_success_message
    expect(page).to have_content("Vaccination outcome recorded for HPV")
  end
end
