# frozen_string_literal: true

describe "Follow-up parent journey" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "Nurse follows up and confirms the refusal" do
    given_an_hpv_programme_is_underway
    and_a_parent_has_submitted_consent_requesting_follow_up

    when_i_navigate_to_the_patient_page
    then_i_see_the_follow_up_requested_status

    when_i_click_through_to_the_consent
    then_i_see_the_follow_up_action

    when_i_start_the_follow_up
    then_i_see_the_follow_up_page

    when_i_try_continuing_without_selecting_a_radio
    then_i_see_an_error_message

    when_i_confirm_the_decision_still_stands
    then_i_see_the_confirm_refusal_page

    when_i_try_continuing_without_selecting_a_radio
    then_i_see_an_error_message

    when_i_confirm_the_refusal_with_notes
    then_the_consent_is_updated_with_a_flash_message
    and_the_parent_receives_a_refusal_confirmation_email
    and_the_parent_receives_a_refusal_confirmation_text
    and_the_consent_is_marked_as_follow_up_confirmed

    when_i_navigate_to_the_patient_page
    then_i_see_the_consent_refused_status

    when_i_view_the_full_child_record_activity_log
    then_i_see_the_follow_up_requested_event_in_the_activity_log
    and_i_see_the_refusal_confirmed_follow_up_resolution_in_the_activity_log
    and_i_do_not_see_an_invalidated_consent_event_in_the_activity_log
    and_i_see_email_and_sms_notifications_in_the_activity_log("confirmed")
  end

  scenario "Nurse follows up and records new consent (refusal withdrawn)" do
    given_an_hpv_programme_is_underway
    and_a_parent_has_submitted_consent_requesting_follow_up

    when_i_navigate_to_the_patient_page
    then_i_see_the_follow_up_requested_status

    when_i_click_through_to_the_consent
    when_i_start_the_follow_up

    when_the_decision_no_longer_stands
    then_i_am_taken_to_the_agree_step

    when_i_record_consent_given
    then_the_consent_is_recorded_with_a_flash_message
    and_the_parent_receives_a_consent_given_email
    and_the_parent_receives_a_consent_given_text
    and_the_new_consent_is_recorded_as_given
    and_the_original_consent_is_resolved_as_withdrawn

    when_i_navigate_to_the_patient_page
    then_i_see_the_consent_given_status

    when_i_view_the_full_child_record_activity_log
    then_i_see_the_follow_up_requested_event_in_the_activity_log
    and_i_see_the_refusal_withdrawn_follow_up_resolution_in_the_activity_log
    and_i_do_not_see_an_invalidated_consent_event_in_the_activity_log
    and_i_see_the_new_consent_given_event_in_the_activity_log
    and_i_see_email_and_sms_notifications_in_the_activity_log("withdrawn")
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    location = create(:school, name: "Pilot School", team: @team)
    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes: [@programme],
        location:
      )
    @patient = create(:patient, session: @session)
  end

  def and_a_parent_has_submitted_consent_requesting_follow_up
    @parent =
      create(
        :parent,
        email: "jane@example.com",
        phone: "07123456789",
        phone_receive_updates: true
      )
    create(:parent_relationship, :mother, parent: @parent, patient: @patient)
    @consent =
      create(
        :consent,
        :follow_up_requested,
        patient: @patient,
        programme: @programme,
        team: @team,
        parent: @parent,
        route: "website",
        submitted_at: Date.new(2025, 7, 1)
      )
    PatientStatusUpdater.call(patient: @patient)
  end

  def when_i_navigate_to_the_patient_page
    sign_in @team.users.first
    visit session_patients_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_the_follow_up_requested_status
    expect(page).to have_content("Follow-up requested")
    expect(page).to have_content(
      "would like to speak to a member of the team about other options"
    )
  end

  def when_i_click_through_to_the_consent
    click_link @parent.full_name
  end

  def then_i_see_the_follow_up_action
    expect(page).to have_link("Follow up")
  end

  def when_i_start_the_follow_up
    click_link "Follow up"
  end

  def then_i_see_the_follow_up_page
    expect(page).to have_content("Follow up refusal")
    expect(page).to have_content("Does their original decision still stand?")
  end

  def when_i_confirm_the_decision_still_stands
    within_fieldset "Does their original decision still stand?" do
      choose "Yes"
    end
    click_button "Continue"
  end

  def then_i_see_the_confirm_refusal_page
    expect(page).to have_content("Update consent response")
    expect(page).to have_content("Confirm consent refusal?")
  end

  def when_i_try_continuing_without_selecting_a_radio
    if page.has_button?("Continue")
      click_button "Continue"
    else
      click_button "Save changes"
    end
  end

  def then_i_see_an_error_message
    expect(page).to have_content("Select yes or no")
  end

  def when_i_confirm_the_refusal_with_notes
    fill_in "Notes", with: "Parent has considered and still refuses."
    within_fieldset "Confirm consent refusal?" do
      choose "Yes"
    end
    click_button "Save changes"
  end

  def then_the_consent_is_updated_with_a_flash_message
    expect(page).to have_content("Consent from #{@parent.full_name} updated.")
  end

  def and_the_parent_receives_a_refusal_confirmation_email
    expect_email_to @parent.email, :consent_confirmation_refused
  end

  def and_the_parent_receives_a_refusal_confirmation_text
    expect_sms_to @parent.phone, :consent_confirmation_refused
  end

  def and_the_consent_is_marked_as_follow_up_confirmed
    expect(@consent.reload).to have_attributes(
      follow_up_requested: false,
      follow_up_outcome: "confirmed",
      follow_up_resolved_at: be_present
    )
  end

  def then_i_see_the_consent_refused_status
    expect(page).to have_content("Consent refused")
    expect(page).to have_content("refused to give consent")
  end

  def when_the_decision_no_longer_stands
    choose "No"
    click_button "Continue"
  end

  def then_i_am_taken_to_the_agree_step
    expect(page).to have_content(
      "Do they agree to them having the HPV vaccination?"
    )
  end

  def when_i_record_consent_given
    choose "Yes, they agree"
    click_button "Continue"

    # Health questions — answer "No" to all
    all("label", text: "No").each(&:click)
    click_button "Continue"

    expect(page).to have_content("Check and confirm answers")
    click_button "Confirm"
  end

  def then_the_consent_is_recorded_with_a_flash_message
    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def and_the_parent_receives_a_consent_given_email
    expect_email_to @parent.email, :consent_confirmation_given
  end

  def and_the_parent_receives_a_consent_given_text
    expect_sms_to @parent.phone, :consent_confirmation_given
  end

  def and_the_new_consent_is_recorded_as_given
    new_consent = @patient.reload.consents.not_invalidated.first
    expect(new_consent).to have_attributes(response: "given")
  end

  def and_the_original_consent_is_resolved_as_withdrawn
    expect(@consent.reload).to have_attributes(
      follow_up_outcome: "withdrawn",
      follow_up_resolved_at: be_present,
      invalidated_at: be_present
    )
  end

  def then_i_see_the_consent_given_status
    expect(page).to have_content("Consent given")
    expect(page).to have_content("is ready for the vaccinator")
  end

  def when_i_view_the_full_child_record_activity_log
    click_link "View full child record"
    click_link @programme.name, match: :first
  end

  def then_i_see_the_follow_up_requested_event_in_the_activity_log
    within(".app-card", text: "Programme activity") do
      expect(page).to have_content(
        "Follow-up requested by #{@parent.full_name} (mum)"
      )
    end
  end

  def and_i_see_the_refusal_confirmed_follow_up_resolution_in_the_activity_log
    within(".app-card", text: "Programme activity") do
      expect(page).to have_content(
        "Consent response from #{@parent.full_name} (mum) followed-up: refusal confirmed"
      )
    end
  end

  def and_i_see_the_refusal_withdrawn_follow_up_resolution_in_the_activity_log
    within(".app-card", text: "Programme activity") do
      expect(page).to have_content(
        "Consent response from #{@parent.full_name} (mum) followed-up: refusal withdrawn"
      )
    end
  end

  def and_i_do_not_see_an_invalidated_consent_event_in_the_activity_log
    within(".app-card", text: "Programme activity") do
      expect(page).not_to have_content(
        "Consent from #{@parent.full_name} invalidated"
      )
    end
  end

  def and_i_see_the_new_consent_given_event_in_the_activity_log
    within(".app-card", text: "Programme activity") do
      expect(page).to have_content(
        "Consent given by #{@parent.full_name} (mum)"
      )
    end
  end

  def and_i_see_email_and_sms_notifications_in_the_activity_log(
    follow_up_outcome
  )
    outcome = follow_up_outcome == "confirmed" ? "refused" : "given"
    within(".app-card", text: "Programme activity") do
      expect(page).to have_content("Consent confirmation #{outcome} sent")
    end
  end
end
