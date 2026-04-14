# frozen_string_literal: true

describe "Self-consent" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  scenario "after Gillick assessment" do
    given_an_hpv_programme_is_underway
    and_there_is_a_child_without_parental_consent

    when_the_nurse_assesses_the_child_as_not_being_gillick_competent
    then_the_details_of_the_gillick_non_competence_assessment_are_visible
    and_the_child_cannot_give_their_own_consent
    and_the_child_status_reflects_that_there_is_no_consent
    and_the_activity_log_shows_the_gillick_non_competence

    when_the_nurse_edits_the_assessment_the_child_as_gillick_competent
    then_the_details_of_the_gillick_competence_assessment_are_visible
    and_the_activity_log_shows_the_gillick_non_competence
    and_the_activity_log_shows_the_gillick_competence
    and_the_nurse_records_consent_for_the_child
    and_the_child_can_give_their_own_consent_that_the_nurse_records

    when_the_nurse_views_the_childs_record
    then_they_see_that_the_child_has_consent_from_themselves
    and_the_child_should_be_safe_to_vaccinate
    and_enqueued_jobs_run_with_no_errors
  end

  scenario "change to parent consent" do
    given_an_hpv_programme_is_underway
    and_there_is_a_child_with_gillick_competence
    and_the_child_has_a_parent

    when_the_nurse_goes_to_the_child
    and_the_nurse_records_consent_for_the_child
    and_changes_the_response_method_to_the_parent
    then_the_parent_can_give_consent

    when_the_nurse_views_the_childs_record
    then_they_see_that_the_child_has_consent_from_the_parent
    and_the_child_should_be_safe_to_vaccinate
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv

    @team = create(:team, :with_one_nurse, programmes: [@programme])

    @school = create(:gias_school, team: @team)

    @session =
      create(
        :session,
        :today,
        team: @team,
        programmes: [@programme],
        location: @school
      )

    @patient = create(:patient, :consent_no_response, session: @session)
  end

  def and_there_is_a_child_without_parental_consent
    sign_in @team.users.first
    visit sessions_path
    click_on @school.name
    within ".app-secondary-navigation" do
      click_on "Children"
    end

    choose "Needs consent"
    click_on "Update results"

    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patient.full_name)
  end

  def and_there_is_a_child_with_gillick_competence
    create(
      :gillick_assessment,
      :competent,
      patient: @patient,
      session: @session,
      programme: @programme
    )
  end

  def and_the_child_has_a_parent
    @parent = create(:parent_relationship, patient: @patient).parent
  end

  def when_the_nurse_goes_to_the_child
    sign_in @team.users.first

    visit session_patient_programme_path(@session, @patient, @programme)
  end

  def when_the_nurse_assesses_the_child_as_not_being_gillick_competent
    click_on @patient.full_name
    click_on "Assess Gillick competence"

    within(
      "fieldset",
      text: "The child knows which vaccination they will have"
    ) { choose "No" }

    within(
      "fieldset",
      text: "The child knows which disease the vaccination protects against"
    ) { choose "No" }

    within(
      "fieldset",
      text: "The child knows what could happen if they got the disease"
    ) { choose "No" }

    within(
      "fieldset",
      text: "The child knows how the vaccination will be given"
    ) { choose "No" }

    within(
      "fieldset",
      text: "The child knows which side effects they might experience"
    ) { choose "No" }

    fill_in "Assessment notes (optional)",
            with: "They didn't understand the benefits and risks of the vaccine"

    click_on "Complete your assessment"

    travel 1.minute
  end

  def then_the_details_of_the_gillick_non_competence_assessment_are_visible
    expect(page).to have_content("Child assessed as not Gillick competent")
    expect(page).to have_content(
      "They didn't understand the benefits and risks of the vaccine"
    )
  end

  def and_the_child_cannot_give_their_own_consent
    click_on "Record a new consent response"
    expect(page).not_to have_content("Child (Gillick competent)")
    click_on "Back"
  end

  def and_the_child_status_reflects_that_there_is_no_consent
    expect(page).to have_content("no parent contact details")
  end

  def and_the_activity_log_shows_the_gillick_non_competence
    click_on "Session activity and notes"
    expect(page).to have_content(
      "Completed Gillick assessment as not Gillick competent"
    )
    click_on "HPV"
  end

  def when_the_nurse_edits_the_assessment_the_child_as_gillick_competent
    click_on "Update Gillick competence"

    # notes from previous assessment
    expect(page).to have_content(
      "They didn't understand the benefits and risks of the vaccine"
    )

    within(
      "fieldset",
      text: "The child knows which vaccination they will have"
    ) { choose "Yes" }

    within(
      "fieldset",
      text: "The child knows which disease the vaccination protects against"
    ) { choose "Yes" }

    within(
      "fieldset",
      text: "The child knows what could happen if they got the disease"
    ) { choose "Yes" }

    within(
      "fieldset",
      text: "The child knows how the vaccination will be given"
    ) { choose "Yes" }

    within(
      "fieldset",
      text: "The child knows which side effects they might experience"
    ) { choose "Yes" }

    fill_in "Assessment notes (optional)",
            with: "They understand the benefits and risks of the vaccine"

    click_on "Update your assessment"

    travel 1.minute
  end

  def then_the_details_of_the_gillick_competence_assessment_are_visible
    expect(page).to have_content("Child assessed as Gillick competent")
    expect(page).to have_content(
      "They understand the benefits and risks of the vaccine"
    )
  end

  def and_the_activity_log_shows_the_gillick_competence
    click_on "Session activity and notes"
    expect(page).to have_content(
      "Updated Gillick assessment as Gillick competent"
    )
    click_on "HPV"
  end

  def and_the_nurse_records_consent_for_the_child
    click_on "Record a new consent response"

    # who
    choose "Child (Gillick competent)"
    click_on "Continue"

    # record consent
    choose "Yes, they agree"
    click_on "Continue"

    # notify parents
    choose "Yes"
    click_on "Continue"

    # answer the health questions
    all("label", text: "No").each(&:click)
    click_on "Continue"
  end

  def and_the_child_can_give_their_own_consent_that_the_nurse_records
    click_on "Change method"

    choose "Child (Gillick competent)"
    4.times { click_on "Continue" }

    expect(page).to have_content("Confirmation of vaccination sent to parent")

    click_on "Confirm"

    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def and_changes_the_response_method_to_the_parent
    click_on "Change method"
    choose @parent.full_name
    click_on "Continue"

    click_on "Continue"

    choose "By phone"
    click_on "Continue"

    2.times { click_on "Continue" }
  end

  def then_the_parent_can_give_consent
    click_on "Confirm"
  end

  def when_the_nurse_views_the_childs_record
    click_on @patient.full_name, match: :first
  end

  def then_they_see_that_the_child_has_consent_from_themselves
    expect(page).to have_content("Consent given")
    expect(page).to have_content("Child (Gillick competent)")
  end

  def then_they_see_that_the_child_has_consent_from_the_parent
    expect(page).to have_content("Consent given")
    expect(page).to have_content(@parent.full_name)
  end

  def and_the_child_should_be_safe_to_vaccinate
    expect(page).to have_content("ready for the vaccinator")
  end

  def and_enqueued_jobs_run_with_no_errors
    expect { perform_enqueued_jobs }.not_to raise_error
  end
end
