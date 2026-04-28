# frozen_string_literal: true

describe "User CIS2 authentication", :cis2 do
  scenario "user has wrong role selected" do
    given_i_am_setup_in_mavis_and_cis2_but_with_the_wrong_role
    when_i_go_to_the_sessions_page
    then_i_am_on_the_start_page
    when_i_click_the_cis2_login_button
    then_i_see_the_wrong_workgroup_error
    and_i_see_my_care_identity_details

    when_i_click_the_change_role_button_and_select_the_right_role
    then_i_see_the_session_page
  end

  def given_i_am_setup_in_mavis_and_cis2_but_with_the_wrong_role
    @team = create(:team, ods_code: "A9A5A")

    mock_cis2_auth(
      workgroups: ["wrong-workgroup"],
      activity_codes: [CIS2Info::INDEPENDENT_PRESCRIBING_ACTIVITY_CODE]
    )
  end

  def when_i_click_the_cis2_login_button
    click_button "Care Identity"
  end

  def then_i_am_on_the_start_page
    expect(page).to have_current_path(start_path)
  end

  def when_i_go_to_the_sessions_page
    visit sessions_path
  end

  def then_i_see_the_session_page
    expect(page).to have_current_path(sessions_path)
  end

  def then_i_see_the_wrong_workgroup_error
    expect(page).to have_heading(
      "You’re not in the right workgroup to use this service"
    )
  end

  def and_i_see_my_care_identity_details
    expect(page).to have_heading("Your Care Identity details")
    expect(page).to have_content("ODS codeA9A5A")
    expect(page).to have_content("Workgroupwrong-workgroup")
    expect(page).to have_content("RoleS8000:G8000:R8001")
    expect(page).to have_content(
      "Activity code#{CIS2Info::INDEPENDENT_PRESCRIBING_ACTIVITY_CODE}"
    )
  end

  def when_i_click_the_change_role_button_and_select_the_right_role
    # With don't actually get to select the right role directly in our test
    # setup so we change the cis2 response to simulate it.
    mock_cis2_auth(
      org_code: @team.organisation.ods_code,
      org_name: @team.name,
      workgroups: [@team.workgroup]
    )
    click_button("Change role")
  end
end
