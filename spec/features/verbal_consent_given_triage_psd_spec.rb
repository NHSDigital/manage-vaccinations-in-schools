# frozen_string_literal: true

describe "Verbal consent" do
  scenario "Given flu nasal spray with PSD" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in
    and_the_patient_has_an_invalidated_psd

    when_i_record_that_verbal_nasal_consent_was_given(add_psd: true)
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_nasal_consent_given

    when_i_confirm_the_consent_response
    and_the_patients_status_is_safe_to_vaccinate_with_nasal_spray
    and_the_patient_has_a_patient_specific_direction
  end

  scenario "Given flu nasal spray without PSD" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_nasal_consent_was_given(add_psd: false)
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_nasal_consent_given

    when_i_confirm_the_consent_response
    and_the_patients_status_is_safe_to_vaccinate_with_nasal_spray
    and_the_patient_doesnt_have_a_patient_specific_direction
  end

  def given_a_flu_programme_is_underway
    @programme = Programme.flu
    programmes = [@programme]
    @team = create(:team, :with_one_nurse, programmes:)
    @session = create(:session, :psd_enabled, team: @team, programmes:)

    @parent = create(:parent)
    @patient = create(:patient, session: @session, parents: [@parent])

    PatientStatusUpdater.call
  end

  def and_i_am_signed_in
    sign_in @team.users.first, role: :prescriber
  end

  def and_the_patient_has_an_invalidated_psd
    create(
      :patient_specific_direction,
      patient: @patient,
      programme: @programme,
      invalidated_at: Time.current
    )
  end

  def when_i_record_that_verbal_nasal_consent_was_given(add_psd:)
    visit session_patients_path(@session)

    click_link @patient.full_name
    click_button "Record a new consent response"

    # Who are you trying to get consent from?
    click_button "Continue"
    expect(page).to have_content(
      "Choose who you are trying to get consent from"
    )

    parent_label =
      @patient
        .parent_relationships
        .includes(:parent)
        .find_by(patient: @patient)
        .label_with_parent

    choose parent_label
    click_button "Continue"

    # Details for parent or guardian
    expect(page).to have_content("Details for #{parent_label}")
    # don't change any details
    click_button "Continue"

    # How was the response given?
    choose "By phone"
    click_button "Continue"

    # Do they agree?
    choose "Yes, for the nasal spray"
    choose "No"
    click_button "Continue"

    fieldsets = find_all(".nhsuk-fieldset")

    8.times { |index| fieldsets[index].choose "No" }

    fieldsets.last.choose "Yes"
    fieldsets.last.fill_in "Give details", with: "Some details"

    click_button "Continue"

    choose "Yes, it’s safe to vaccinate with nasal spray"
    choose add_psd ? "Yes" : "No"
    click_button "Continue"
  end

  def then_i_see_the_check_and_confirm_page
    expect(page).to have_content("Check and confirm answers")
    expect(page).to have_content(["Method", "By phone"].join)
    expect(page).not_to have_content(
      "Confirmation of vaccination sent to parent"
    )
  end

  def and_i_see_the_flu_nasal_consent_given
    expect(page).to have_content("ResponseConsent given")
    expect(page).to have_content("Chosen vaccineNasal spray only")
  end

  def when_i_confirm_the_consent_response
    click_button "Confirm"
    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def and_the_patients_status_is_safe_to_vaccinate_with_nasal_spray
    click_link @patient.full_name, match: :first
    expect(page).to have_content("Safe to vaccinate with nasal spray")
  end

  def and_the_patient_has_a_patient_specific_direction
    expect(page).to have_content("PSD added")
  end

  def and_the_patient_doesnt_have_a_patient_specific_direction
    expect(page).to have_content("PSD not added")
  end
end
