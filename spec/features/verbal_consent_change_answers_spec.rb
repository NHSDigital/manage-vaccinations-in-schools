# frozen_string_literal: true

describe "Verbal consent" do
  scenario "Change answers" do
    given_a_patient_is_in_an_hpv_programme

    when_i_get_consent_for_the_patient
    and_i_choose_the_parent
    and_i_fill_out_the_consent_details(
      parent_name: @parent.full_name,
      relationship: "Mum"
    )
    then_i_see_the_confirmation_page

    when_i_click_on_change_name
    and_i_fill_out_the_consent_details(
      parent_name: "New parent name",
      relationship: "Dad"
    )
    then_i_see_the_confirmation_page

    when_i_confirm_the_consent
    and_i_click_on_the_patient
    then_i_see_the_new_parent_details
  end

  def given_a_patient_is_in_an_hpv_programme
    programmes = [Programme.hpv]
    team = create(:team, programmes:)

    @nurse = create(:nurse, team:)

    @session = create(:session, team:, programmes:)

    @parent = create(:parent)
    @patient = create(:patient, session: @session)

    @parent_relationship =
      create(:parent_relationship, :mother, patient: @patient, parent: @parent)

    PatientStatusUpdater.call
  end

  def when_i_get_consent_for_the_patient
    sign_in @nurse
    visit session_patients_path(@session)
    click_link @patient.full_name
    click_on "Record a new consent response"
  end

  def and_i_choose_the_parent
    click_button "Continue"
    expect(page).to have_content(
      "Choose who you are trying to get consent from"
    )

    choose "#{@parent.full_name} (mum)"
    click_button "Continue"
  end

  def and_i_fill_out_the_consent_details(parent_name:, relationship:)
    expect(page).to have_content(
      "Details for #{parent_name} (#{relationship.downcase_first})"
    )

    fill_in "Full name", with: "New parent name"
    choose "Dad"
    click_button "Continue"

    choose "By phone"
    click_button "Continue"

    choose "Yes, they agree"
    click_button "Continue"

    find_all(".nhsuk-fieldset")[0].choose "No"
    find_all(".nhsuk-fieldset")[1].choose "No"
    find_all(".nhsuk-fieldset")[2].choose "No"
    find_all(".nhsuk-fieldset")[3].choose "No"
    click_button "Continue"
  end

  def then_i_see_the_confirmation_page
    expect(page).to have_content("Check and confirm answers")
    expect(page).to have_content("New parent name")
    expect(page).to have_content("Dad")
  end

  def when_i_click_on_change_name
    click_link "Change name"
  end

  def when_i_confirm_the_consent
    click_button "Confirm"
  end

  def and_i_click_on_the_patient
    click_link @patient.full_name, match: :first
  end

  def then_i_see_the_new_parent_details
    expect(page).to have_content("New parent name")
    expect(page).to have_content("Dad")
  end
end
