# frozen_string_literal: true

describe "Flu vaccination" do
  scenario "Prescriber bulk add PSDs to patients that don't require triage" do
    given_a_flu_session_exists(user_type: :with_one_nurse)
    and_patients_exist
    and_the_patient_has_an_invalidated_psd
    and_i_am_signed_in(role: :prescriber)

    when_i_go_to_the_session_psds_tab
    then_the_patients_should_have_psd_status_not_added
    and_i_should_only_see_one_child_eligible_for_bulk_adding_psd
    and_i_should_see_one_child_eligible_for_psd

    when_i_click_add_new_psds
    and_should_see_again_one_child_eligible_for_psd

    when_i_click_on_button_to_bulk_add_psds
    then_the_nasal_patient_should_have_psd_status_added
    and_the_injection_patient_should_have_psd_status_not_added
    and_zero_children_should_be_eligible_for_psd
  end

  scenario "Admin cannot bulk add PSDs to patients" do
    given_a_flu_session_exists(user_type: :with_one_admin)
    and_patients_exist
    and_i_am_signed_in(role: :medical_secretary)

    when_i_go_to_the_session_psds_tab
    then_i_should_not_see_link_to_bulk_add_psds
  end

  scenario "HCAs cannot bulk add PSDs to patients" do
    given_a_flu_session_exists(user_type: :with_one_healthcare_assistant)
    and_patients_exist
    and_i_am_signed_in(role: :healthcare_assistant)

    when_i_go_to_the_session_psds_tab
    then_i_should_not_see_link_to_bulk_add_psds
  end

  scenario "Viewing patients under record tab that don't have PSD" do
    given_a_flu_session_exists(user_type: :with_one_healthcare_assistant)
    and_patients_exist
    and_i_am_signed_in(role: :healthcare_assistant)

    when_i_visit_the_record_vaccinations_tab
    then_i_should_not_see_the_patient
  end

  scenario "Viewing a patient page with no PSD" do
    given_a_flu_session_exists(user_type: :with_one_healthcare_assistant)
    and_patients_exist
    and_i_am_signed_in(role: :healthcare_assistant)

    when_i_visit_the_record_vaccinations_tab
    then_i_should_not_see_the_patient

    when_i_visit_the_session_patient_programme_page
    then_i_should_not_see_the_record_vaccination_section
  end

  scenario "Nasal flu administered by HCA under PSD" do
    given_a_flu_session_exists(user_type: :with_one_healthcare_assistant)
    and_patients_exist
    and_the_nasal_only_patient_has_a_psd
    and_i_am_signed_in(role: :healthcare_assistant)

    when_i_visit_the_record_vaccinations_tab
    and_i_click_on_the_nasal_only_patient
    then_i_am_able_to_vaccinate_them_with_nasal_via_psd
    and_the_vaccination_record_has_psd_as_the_protocol

    when_i_visit_the_session_activity_page
    then_i_see_no_psd_status_tag
  end

  scenario "Nasal flu cannot be administered without a PSD even if national protocol enabled" do
    given_a_flu_session_exists(
      user_type: :with_one_healthcare_assistant,
      national_protocol_enabled: true
    )
    and_patients_exist
    and_i_am_signed_in(role: :healthcare_assistant)

    when_i_visit_the_session_patient_programme_page
    then_i_should_not_see_the_record_vaccination_section
  end

  def given_a_flu_session_exists(user_type:, national_protocol_enabled: false)
    @programme = Programme.flu
    @programmes = [@programme]
    @team = create(:team, user_type, programmes: @programmes)
    @user = create(:nurse, team: @team)

    @batch =
      create(
        :batch,
        :not_expired,
        team: @team,
        vaccine: @programme.vaccines.nasal.first
      )

    @session =
      create(
        :session,
        :today,
        :requires_no_registration,
        :psd_enabled,
        team: @team,
        programmes: @programmes,
        national_protocol_enabled:
      )
  end

  def and_patients_exist
    @patient_nasal_only =
      create(
        :patient,
        :consent_given_nasal_only_triage_not_needed,
        :in_attendance,
        session: @session
      )
    @patient_injection_only =
      create(
        :patient,
        :consent_given_injection_only_triage_not_needed,
        session: @session
      )
  end

  def and_the_patient_has_an_invalidated_psd
    create(
      :patient_specific_direction,
      patient: @patient_nasal_only,
      programme: @programme,
      invalidated_at: Time.current
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

  def and_i_am_signed_in(role:)
    sign_in @team.users.first, role:
  end

  def when_i_go_to_the_session_psds_tab
    visit session_patient_specific_directions_path(@session)
  end

  def when_i_visit_the_record_vaccinations_tab
    visit session_record_path(@session)
  end

  def and_i_click_on_the_nasal_only_patient
    click_on @patient_nasal_only.full_name
  end

  def when_i_visit_the_session_patient_programme_page
    visit session_patient_programme_path(
            @session,
            @patient_nasal_only,
            @programme
          )
  end

  def then_the_patients_should_have_psd_status_not_added
    expect(page).to have_text("PSD not added")
  end

  def then_the_nasal_patient_should_have_psd_status_added
    expect_patient_to_have_psd_status(@patient_nasal_only, "PSD added")
  end

  def and_the_injection_patient_should_have_psd_status_not_added
    expect_patient_to_have_psd_status(@patient_injection_only, "PSD not added")
  end

  def and_i_should_see_one_child_eligible_for_psd
    expect(page).to have_text("There is 1 child")
  end

  def and_should_see_again_one_child_eligible_for_psd
    expect(page).to have_text("1 new PSD?")
  end

  def and_zero_children_should_be_eligible_for_psd
    expect(page).to have_text("There are 0 children")
  end

  def when_i_click_add_new_psds
    click_link "Add new PSDs"
  end

  def when_i_click_on_button_to_bulk_add_psds
    click_button "Yes, add PSD"
  end

  def then_i_should_not_see_link_to_bulk_add_psds
    expect(page).not_to have_text("Add new PSDs")
  end

  def and_i_should_only_see_one_child_eligible_for_bulk_adding_psd
    expect(page).to have_text(
      "There is 1 child with consent for the nasal flu vaccine"
    )
  end

  def expect_patient_to_have_psd_status(patient, status)
    full_name = "#{patient.family_name.upcase}, #{patient.given_name}"
    patient_link = page.find("a", text: full_name)
    patient_card = patient_link.ancestor(".nhsuk-card")
    expect(patient_card).to have_css(".nhsuk-tag", text: status)
  end

  def then_i_should_not_see_the_patient
    expect(page).not_to have_text(@patient_nasal_only.given_name)
  end

  def then_i_should_not_see_the_record_vaccination_section
    expect(page).not_to have_text(
      "Record flu vaccination with gelatine-free injection"
    )
  end

  def then_i_am_able_to_vaccinate_them_with_nasal_via_psd
    within all("form")[2] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      within all("fieldset")[2] do
        choose "Yes"
      end

      click_button "Continue"
    end

    choose @batch.number
    click_button "Continue"

    expect(page).to have_content("ProtocolPatient Specific Direction")
    expect(page).to have_content("Supplier#{@user.full_name}")

    click_on "Confirm"

    expect(page).to have_text("Vaccination outcome recorded for flu")
  end

  def and_the_vaccination_record_has_psd_as_the_protocol
    expect(@patient_nasal_only.vaccination_records.first.protocol).to eq("psd")
  end

  def when_i_visit_the_session_activity_page
    click_on "Session activity"
  end

  def then_i_see_no_psd_status_tag
    expect(page).not_to have_css(".nhsuk-tag", text: "PSD added")
    expect(page).not_to have_css(".nhsuk-tag", text: "PSD not added")
  end
end
