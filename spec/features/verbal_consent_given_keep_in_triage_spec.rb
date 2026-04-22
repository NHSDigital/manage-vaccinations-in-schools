# frozen_string_literal: true

describe "Verbal consent" do
  scenario "Given, keep in triage" do
    given_i_am_signed_in

    when_i_record_that_consent_was_given_but_keep_in_triage

    then_an_email_is_sent_to_the_parent_about_triage
    and_the_patient_status_is_needing_triage
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    team = create(:team, :with_one_nurse, programmes:)
    @session = create(:session, team:, programmes:)

    @parent = create(:parent)
    @patient = create(:patient, session: @session, parents: [@parent])

    PatientStatusUpdater.call

    sign_in team.users.first
  end

  def when_i_record_that_consent_was_given_but_keep_in_triage
    visit session_patients_path(@session)
    click_link @patient.full_name
    click_button "Record a new consent response"

    # Who are you trying to get consent from?
    choose @parent.full_name
    click_button "Continue"

    # Details for parent or guardian: leave prepopulated details
    click_button "Continue"

    # How was the response given?
    choose "By phone"
    click_button "Continue"

    # Do they agree?
    choose "Yes, they agree"
    click_button "Continue"

    # Health questions
    find_all(".nhsuk-fieldset")[0].choose "Yes"
    find_all(".nhsuk-fieldset")[0].fill_in "Give details",
              with: "moar allergies"
    find_all(".nhsuk-fieldset")[1].choose "No"
    find_all(".nhsuk-fieldset")[2].choose "No"
    find_all(".nhsuk-fieldset")[3].choose "No"
    click_button "Continue"

    choose "No, keep in triage"
    fill_in "Triage notes (optional)", with: "Some notes."
    click_button "Continue"

    # Confirm
    click_button "Confirm"

    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def and_the_patient_status_is_needing_triage
    click_link @patient.full_name, match: :first
    expect(page).to have_content("Needs triage")
    expect(page).to have_content("Some notes.")
  end

  def then_an_email_is_sent_to_the_parent_about_triage
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template: :consent_confirmation_triage
      ).with_content_including(
        "we’ll review your answers",
        "We’ll contact you if we need to delay or cancel the vaccination."
      )
    )
  end
end
