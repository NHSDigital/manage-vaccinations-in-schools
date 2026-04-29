# frozen_string_literal: true

describe "Flu vaccination" do
  around { |example| travel_to(Time.zone.local(2024, 10, 1)) { example.run } }

  scenario "Administered by HCA under national protocol" do
    given_a_session_exists
    and_patients_exist

    when_i_visit_the_session_record_tab
    then_i_see_all_the_patients

    when_i_click_on_the_nasal_only_patient
    then_i_am_able_to_vaccinate_them(nasal: true)

    when_i_click_on_the_nasal_and_injection_patient
    then_i_am_able_to_vaccinate_them(nasal: true)

    when_i_click_on_the_injection_patient
    then_i_am_able_to_vaccinate_them(nasal: false)
  end

  scenario "Administered by HCA under national protocol but had a previous PSD" do
    given_a_session_exists
    and_patients_exist
    and_the_nasal_and_injection_patient_has_a_psd

    when_i_visit_the_session_record_tab
    then_i_see_all_the_patients

    when_i_click_on_the_nasal_and_injection_patient
    then_i_am_able_to_vaccinate_them(nasal: true)
  end

  scenario "Administered by HCA under national protocol with PSD enabled" do
    given_a_session_exists(psd_enabled: true)
    and_patients_exist
    and_the_nasal_and_injection_patient_has_a_psd

    when_i_visit_the_session_record_tab
    then_i_see_only_the_injection_patients

    when_i_click_on_the_nasal_and_injection_patient
    then_i_am_able_to_vaccinate_them_using_injection_instead_of_nasal
  end

  scenario "HCA viewing record tab where national protocol is turned off and patient triaged for injection" do
    given_a_session_exists(national_protocol_enabled: false)
    and_a_nasal_and_injection_patient_exists_triaged_as_safe_vaccinate_with_injection

    when_i_visit_the_session_record_tab
    then_i_should_not_see_the_patient
  end

  def given_a_session_exists(
    psd_enabled: false,
    national_protocol_enabled: true
  )
    @programme = Programme.flu
    programmes = [@programme]

    @team = create(:team, programmes:)

    @nasal_batch =
      create(
        :batch,
        :not_expired,
        team: @team,
        vaccine: @programme.vaccines.nasal.first
      )

    @injection_batch =
      create(
        :batch,
        :not_expired,
        team: @team,
        vaccine: @programme.vaccines.injection.first
      )

    @nurse = create(:nurse, team: @team)
    @user = create(:healthcare_assistant, team: @team)

    @session =
      create(
        :session,
        :today,
        :requires_no_registration,
        :national_protocol_enabled,
        team: @team,
        programmes:,
        psd_enabled:,
        national_protocol_enabled:
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

  def and_a_nasal_and_injection_patient_exists_triaged_as_safe_vaccinate_with_injection
    @patient_nasal_and_injection =
      create(
        :patient,
        :consent_given_injection_and_nasal_triage_safe_to_vaccinate_injection,
        session: @session
      )
  end

  def and_the_nasal_and_injection_patient_has_a_psd
    create(
      :patient_specific_direction,
      academic_year: @session.academic_year,
      patient: @patient_nasal_and_injection,
      programme: @programme,
      team: @team
    )
  end

  def when_i_visit_the_session_record_tab
    sign_in @user, role: :healthcare_assistant
    visit session_record_path(@session)
  end

  def then_i_see_all_the_patients
    expect(page).to have_content(@patient_nasal_only.full_name)
    expect(page).to have_content(@patient_nasal_and_injection.full_name)
    expect(page).to have_content(@patient_injection_only.full_name)
  end

  def then_i_see_only_the_injection_patients
    expect(page).not_to have_content(@patient_nasal_only.full_name)
    expect(page).to have_content(@patient_nasal_and_injection.full_name)
    expect(page).to have_content(@patient_injection_only.full_name)
  end

  def then_i_should_not_see_the_patient
    expect(page).not_to have_content(@patient_nasal_and_injection.full_name)
  end

  def when_i_click_on_the_nasal_only_patient
    click_on @patient_nasal_only.full_name
  end

  def when_i_click_on_the_nasal_and_injection_patient
    click_on @patient_nasal_and_injection.full_name
  end

  def when_i_click_on_the_injection_patient
    click_on @patient_injection_only.full_name
  end

  def then_i_am_able_to_vaccinate_them(nasal:)
    within all("form")[2] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      select @nurse.full_name

      within all("fieldset")[2] do
        choose "Yes"
        choose "Left arm (upper position)" unless nasal
      end

      click_on "Continue"
    end

    batch = nasal ? @nasal_batch : @injection_batch

    choose batch.number
    click_on "Continue"

    click_on "Change supplier"
    choose @nurse.full_name
    (nasal ? 4 : 3).times { click_on "Continue" }

    protocol = nasal ? "Patient Group Direction (PGD)" : "National"

    expect(page).to have_content("Protocol#{protocol}")

    click_on "Confirm"
    click_on "Record vaccinations"
  end

  def then_i_am_able_to_vaccinate_them_using_injection_instead_of_nasal
    within find("form[action*='vaccinations']") do
      check "I have checked that the above statements are true"
      within find("fieldset", text: "ready for their") do
        choose "No — but they can have the injected flu instead"
        choose "Left arm (upper position)"
        select @nurse.full_name
      end

      click_on "Continue"
    end

    choose @injection_batch.number
    click_on "Continue"

    expect(page).to have_content("ProtocolNational")

    click_on "Confirm"
    click_on "Record vaccinations"
  end
end
