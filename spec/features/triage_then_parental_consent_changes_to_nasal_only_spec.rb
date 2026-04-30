# frozen_string_literal: true

describe "Triage" do
  scenario "Nurse triages a flu patient for injection and then the same parent changes consent to nasal only" do
    given_a_flu_programme_with_a_running_session

    when_the_parent_gives_consent_for_nasal_spray_and_injection
    and_the_nurse_triages_the_patient_as_safe_for_injection_only
    then_i_can_record_an_injection_for_the_patient

    when_the_same_parent_changes_consent_to_nasal_only
    and_i_go_to_the_patient_that_needs_triage
    then_i_cannot_record_an_injection_for_the_patient
  end

  def given_a_flu_programme_with_a_running_session
    @programme = Programme.flu
    team = create(:team, :with_one_nurse, programmes: [@programme])
    @nurse = team.users.first
    location = create(:gias_school, team:)
    @session =
      create(
        :session,
        team:,
        programmes: [@programme],
        location:,
        dates: [Date.current, Date.tomorrow]
      )
    @patient = create(:patient, :in_attendance, session: @session)
    @parent = create(:parent)

    sign_in @nurse
  end

  def when_the_parent_gives_consent_for_nasal_spray_and_injection
    submit_parental_consent_form(accept_injection_alternative: true)
  end

  def and_the_nurse_triages_the_patient_as_safe_for_injection_only
    visit session_patients_path(@session)

    choose "Due vaccination"
    click_on "Update results"
    click_link @patient.full_name

    click_link "Update triage outcome"
    choose "Yes, it’s safe to vaccinate with injected vaccine"
    click_button "Save triage"
  end

  def then_i_can_record_an_injection_for_the_patient
    expect(page).to have_content(
      "Record flu vaccination with gelatine-free injection"
    )
    expect(page).to have_content(
      "Is #{@patient.given_name} ready for their flu injection?"
    )
  end

  def when_the_same_parent_changes_consent_to_nasal_only
    travel 1.minute
    submit_parental_consent_form(accept_injection_alternative: false)
  end

  def and_i_go_to_the_patient_that_needs_triage
    visit session_patient_programme_path(@session, @patient, @programme)
  end

  def then_i_cannot_record_an_injection_for_the_patient
    expect(page).to have_content("Flu: Needs triage")
    expect(page).not_to have_content(
      "Record flu vaccination with gelatine-free injection"
    )
    expect(page).not_to have_content(
      "Is #{@patient.given_name} ready for their flu injection?"
    )
  end

  def submit_parental_consent_form(accept_injection_alternative:)
    visit start_parent_interface_consent_forms_path(@session, @programme)

    click_button "Start now"

    fill_in "First name", with: @patient.given_name
    fill_in "Last name", with: @patient.family_name
    choose "No"
    click_button "Continue"

    fill_in "Day", with: @patient.date_of_birth.day
    fill_in "Month", with: @patient.date_of_birth.month
    fill_in "Year", with: @patient.date_of_birth.year
    click_button "Continue"

    choose "Yes"
    click_button "Continue"

    fill_in "Full name", with: @parent.full_name
    choose "Mum"
    fill_in "Email address", with: @parent.email
    fill_in "Phone number", with: @parent.phone
    check "Tick this box if you’d like to get updates by text message"
    click_button "Continue"

    choose "I do not have specific needs"
    click_button "Continue"

    choose "Yes, I agree to them having the nasal spray vaccine"
    click_button "Continue"

    choose(accept_injection_alternative ? "Yes" : "No")
    click_button "Continue"

    fill_in "Address line 1", with: "1 High Street"
    fill_in "Town or city", with: "London"
    fill_in "Postcode", with: "SW1 1AA"
    click_button "Continue"

    answer_no_to_all_health_questions_until_confirmation_page

    perform_enqueued_jobs { click_button "Confirm" }
  end

  def answer_no_to_all_health_questions_until_confirmation_page
    12.times do
      break if page.has_content?("Check and confirm")

      choose "No"
      click_button "Continue"
    end
  end
end
