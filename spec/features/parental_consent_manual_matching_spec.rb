# frozen_string_literal: true

describe "Parental consent manual matching" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before { given_the_app_is_setup }

  scenario "Consent isn't matched automatically so nurse matches it manually" do
    when_i_go_to_the_dashboard
    and_i_click_on_unmatched_consent_responses
    then_i_am_on_the_unmatched_responses_page
    and_i_see_one_response

    when_i_choose_a_consent_response
    then_i_am_on_the_consent_matching_page
    and_i_see_no_patients

    when_i_search_for_the_child
    then_i_see_patients

    when_i_select_the_child_record
    then_i_can_review_the_match

    when_i_link_the_response_with_the_record
    and_i_click_on_the_patient
    then_the_parent_consent_is_shown

    when_i_click_on_the_activity_log
    then_i_see_the_consent_was_matched_manually
    and_i_do_not_see_any_consent_contact_warning_notifications
  end

  scenario "Consent isn't matched automatically, nurse matches it manually, patient is not eligible for programme" do
    given_the_patient_has_aged_out_of_the_programme

    when_i_go_to_the_dashboard
    and_i_click_on_unmatched_consent_responses
    then_i_am_on_the_unmatched_responses_page
    and_i_see_one_response

    when_i_choose_a_consent_response
    then_i_am_on_the_consent_matching_page
    and_i_see_no_patients

    when_i_search_for_the_aged_out_child
    then_i_see_patients

    when_i_select_the_child_record
    then_i_can_review_the_match

    when_i_link_the_response_with_the_record
    and_i_click_on_the_patient
    then_the_parent_consent_is_shown
    and_the_patient_is_not_in_a_session
  end

  scenario "Consent is marked as invalid" do
    when_i_go_to_the_dashboard
    and_i_click_on_unmatched_consent_responses
    then_i_am_on_the_unmatched_responses_page
    and_i_see_one_response

    when_i_choose_to_archive_the_response
    then_i_fill_in_the_notes
    and_i_archive_the_response

    then_i_am_on_the_unmatched_responses_page
    and_i_see_the_archived_message
    and_i_see_no_responses
  end

  def given_the_app_is_setup
    programmes = [Programme.hpv]

    @team = create(:team, :with_one_nurse, programmes:)
    @user = @team.users.first
    @school = create(:school, name: "Pilot School", team: @team)
    @session = create(:session, location: @school, team: @team, programmes:)
    @consent_form =
      create(
        :consent_form,
        :recorded,
        session: @session,
        parent_full_name: "John Smith",
        parent_email: "john.smith@example.com"
      )
    @patient = create(:patient, session: @session)
    create(:vaccination_record, patient: @patient)
    @parent = create(:parent, email: "eliza.smith@example.com")
    create(:parent_relationship, :mother, parent: @parent, patient: @patient)
  end

  def given_the_patient_has_aged_out_of_the_programme
    @consent_form.update!(date_of_birth: @consent_form.date_of_birth - 5.years)
    @patient.update!(birth_academic_year: @patient.birth_academic_year - 5)
  end

  def when_i_go_to_the_dashboard
    sign_in @user
    visit dashboard_path
    expect(page).to have_content("Unmatched responses (1)")
  end

  def and_i_click_on_unmatched_consent_responses
    click_on "Unmatched consent responses"
  end

  def then_i_am_on_the_unmatched_responses_page
    expect(page).to have_content("Unmatched consent responses")
  end

  def and_i_see_one_response
    expect(page).to have_content("1 unmatched consent response")
  end

  def when_i_choose_a_consent_response
    click_on "Match"
  end

  def then_i_am_on_the_consent_matching_page
    expect(page).to have_content("Search for a child record")
  end

  def and_i_see_no_patients
    expect(page).to have_content(
      "Search for a child or use filters to see children matching your selection."
    )
  end

  def then_i_see_patients
    expect(page).to have_content(@patient.full_name)
  end

  def when_i_search_for_the_child
    fill_in "Search", with: @patient.full_name
    click_button "Search"
  end

  def when_i_search_for_the_aged_out_child
    fill_in "Search", with: @patient.full_name
    find(".nhsuk-details__summary").click
    check "Children aged out of programmes"
    click_button "Search"
  end

  def when_i_select_the_child_record
    click_link @patient.full_name
  end

  def then_i_can_review_the_match
    expect(page).to have_content("Link consent response with child record?")
  end

  def when_i_link_the_response_with_the_record
    click_on "Link response with record"
    expect(page).to have_content("Unmatched responses (0)")
  end

  def and_i_click_on_the_patient
    click_on @patient.full_name
  end

  def then_the_parent_consent_is_shown
    expect(page).to have_content(@consent_form.parent_full_name)
  end

  def and_the_patient_is_not_in_a_session
    expect(page).not_to have_content("Session activity and notes")
  end

  def when_i_click_on_the_activity_log
    click_on "Session activity and notes"
  end

  def then_i_see_the_consent_was_matched_manually
    expect(page).to have_content(
      "Consent response manually matched with child record"
    )
  end

  def and_i_do_not_see_any_consent_contact_warning_notifications
    expect(page).not_to have_content(
      "Consent unknown contact details warning sent"
    )
    expect(page).not_to have_content(@parent.email)
  end

  def when_i_choose_to_archive_the_response
    click_on "Archive"
  end

  def then_i_fill_in_the_notes
    fill_in "Notes", with: "Some notes."
  end

  def and_i_archive_the_response
    click_on "Archive response"
  end

  def and_i_see_the_archived_message
    expect(page).to have_content("Consent response from John Smith archived")
  end

  def and_i_see_no_responses
    expect(page).to have_content(
      "There are currently no unmatched consent responses."
    )
  end
end
