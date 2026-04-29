# frozen_string_literal: true

describe "Flu vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 10, 1)) { example.run } }

  scenario "Administered by HCA under PGD supply" do
    given_a_session_exists
    and_patients_exist

    when_i_visit_the_session_record_tab
    then_i_only_see_nasal_spray_patients

    when_i_click_on_the_nasal_only_patient
    then_i_am_able_to_vaccinate_them_nasal_only

    when_i_click_on_the_nasal_and_injection_patient
    then_i_am_able_to_vaccinate_them_nasal_only

    when_i_click_on_the_injection_patient
    then_i_am_not_able_to_vaccinate_them
  end

  scenario "Administered by HCA under PGD supply, patient has previous PSD" do
    given_a_session_exists
    and_patients_exist
    and_the_nasal_only_patient_has_a_psd

    when_i_visit_the_session_record_tab
    then_i_only_see_nasal_spray_patients

    when_i_click_on_the_nasal_only_patient
    then_i_am_able_to_vaccinate_them_nasal_only
  end

  scenario "Patient consents nasal, has health issues, and is triaged as safe to vaccinate" do
    given_a_session_exists
    and_a_nasal_patient_exists_with_health_issues_marked_safe_vaccinate_with_nasal

    when_i_visit_the_session_record_tab
    and_i_click_on_the_nasal_only_patient
    then_i_am_able_to_vaccinate_them_nasal_only
  end

  def given_a_session_exists
    @programme = Programme.flu
    programmes = [@programme]

    @team = create(:team, programmes:)

    @batch =
      create(
        :batch,
        :not_expired,
        team: @team,
        vaccine: @programme.vaccines.nasal.first
      )

    @nurse =
      create(:nurse, team: @team, given_name: "Supplying", family_name: "Nurse")
    @user = create(:healthcare_assistant, team: @team)

    @session =
      create(
        :session,
        :today,
        :requires_no_registration,
        team: @team,
        programmes:
      )
  end

  def and_patients_exist
    @patient_nasal_only =
      create(
        :patient,
        :in_attendance,
        :consent_given_nasal_only_triage_not_needed,
        session: @session
      )
    @patient_nasal_and_injection =
      create(
        :patient,
        :in_attendance,
        :consent_given_nasal_or_injection_triage_not_needed,
        session: @session
      )
    @patient_injection_only =
      create(
        :patient,
        :in_attendance,
        :consent_given_injection_only_triage_not_needed,
        session: @session
      )
  end

  def and_the_nasal_only_patient_has_a_psd
    create(
      :patient_specific_direction,
      patient: @patient_nasal_only,
      programme: @programme,
      team: @team
    )
  end

  def and_a_nasal_patient_exists_with_health_issues_marked_safe_vaccinate_with_nasal
    @patient_nasal_only =
      create(
        :patient,
        :in_attendance,
        :consent_given_nasal_triage_safe_to_vaccinate_nasal,
        session: @session
      )
  end

  def when_i_visit_the_session_record_tab
    sign_in @user, role: :healthcare_assistant
    visit session_record_path(@session)
  end

  def then_i_only_see_nasal_spray_patients
    expect(page).to have_content(@patient_nasal_only.full_name)
    expect(page).to have_content(@patient_nasal_and_injection.full_name)
    expect(page).not_to have_content(@patient_injection_only.full_name)
  end

  def when_i_click_on_the_nasal_only_patient
    click_on @patient_nasal_only.full_name
  end
  alias_method :and_i_click_on_the_nasal_only_patient,
               :when_i_click_on_the_nasal_only_patient

  def when_i_click_on_the_nasal_and_injection_patient
    click_on @patient_nasal_and_injection.full_name
  end

  def when_i_click_on_the_injection_patient
    # This patient won't be in the "Record" tab.
    expect(page).not_to have_content(@patient_injection_only.full_name)

    within(".app-secondary-navigation") { click_on "Children" }
    click_on @patient_injection_only.full_name
  end

  def then_i_am_able_to_vaccinate_them_nasal_only
    expect(page).not_to have_content("injected flu instead")

    within all("form")[2] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      select "NURSE, Supplying"

      within all("fieldset")[2] do
        choose "Yes"
      end

      click_on "Continue"
    end

    choose @batch.number
    click_on "Continue"

    click_on "Change supplier"
    choose @nurse.full_name
    4.times { click_on "Continue" }

    click_on "Confirm"
    click_on "Record vaccinations"
  end

  def then_i_am_not_able_to_vaccinate_them
    expect(page).not_to have_content("Pre-screening checks")
    expect(page).not_to have_content("ready for their")
  end
end
