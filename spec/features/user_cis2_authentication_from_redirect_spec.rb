# frozen_string_literal: true

describe "User CIS2 authentication", :cis2 do
  include RedirectHelper

  scenario "from redirect" do
    given_a_test_team_is_setup_in_mavis_and_cis2
    when_i_go_to_the_sessions_page
    then_i_am_on_the_start_page

    when_i_click_the_cis2_login_button
    then_i_see_the_sessions_page
    and_i_am_logged_in
  end

  scenario "from reporting" do
    given_a_test_team_is_setup_in_mavis_and_cis2
    when_i_go_to_the_start_page_with_a_redirect_uri_param_that_matches_the_reporting_app

    when_i_click_the_cis2_login_button
    then_i_am_redirected_to_the_previously_stored_redirect_uri_param
    and_the_return_url_has_a_token_param_added_to_it
  end

  scenario "someone has supplied their own absolute redirect url" do
    given_a_test_team_is_setup_in_mavis_and_cis2
    when_i_go_to_the_start_page_with_a_redirect_uri_param_that_does_not_match_the_reporting_app

    when_i_click_the_cis2_login_button
    then_i_see_the_dashboard
  end

  scenario "someone has supplied their own schema-relative redirect url" do
    given_a_test_team_is_setup_in_mavis_and_cis2
    when_i_go_to_the_start_page_with_a_redirect_uri_param_that_is_schema_relative

    when_i_click_the_cis2_login_button
    then_i_see_the_dashboard
  end

  def given_a_test_team_is_setup_in_mavis_and_cis2
    @user = create(:user, uid: "123")
    @team = create(:team, users: [@user])

    mock_cis2_auth(
      uid: "123",
      given_name: "Nurse",
      family_name: "Test",
      org_code: @team.organisation.ods_code,
      org_name: @team.name,
      workgroups: [@team.workgroup]
    )
  end

  def return_url_on_reporting_app
    reporting_app_url(
      "/some/reporting/path?month=6&school_id=123&search=some search string"
    )
  end

  def return_url_on_mavis_reporting_ah_token_added
    reporting_app_url(
      "/some/reporting/path?code=mylonghextoken&month=6&school_id=123&search=some search string"
    )
  end

  def when_i_go_to_the_start_page_with_a_redirect_uri_param_that_matches_the_reporting_app
    uri = URI.encode_uri_component(return_url_on_reporting_app)
    visit [start_path, "redirect_uri=#{uri}"].join("?")
  end

  def when_i_go_to_the_start_page_with_a_redirect_uri_param_that_is_schema_relative
    uri =
      URI.encode_uri_component("https://some.example.com/redirect/elsewhere")
    visit [start_path, "redirect_uri=#{uri}"].join("?")
  end

  def when_i_go_to_the_start_page_with_a_redirect_uri_param_that_does_not_match_the_reporting_app
    uri = URI.encode_uri_component("//some.example.com/redirect/elsewhere")
    visit [start_path, "redirect_uri=#{uri}"].join("?")
  end

  def then_i_am_redirected_to_the_previously_stored_redirect_uri_param
    then_i_am_redirected_to_a_url_matching return_url_on_reporting_app
  end

  def and_the_return_url_has_a_token_param_added_to_it
    expect(page.driver.browser.current_url).to match(/code=[a-gA-G0-9]{32}/)
  end

  def when_i_go_to_the_sessions_page
    visit sessions_path
  end

  def then_i_am_on_the_start_page
    expect(page).to have_current_path start_path
  end

  def when_i_click_the_cis2_login_button
    click_button "Care Identity"
  end

  def then_i_see_the_sessions_page
    expect(page).to have_current_path(sessions_path)
  end

  def and_i_am_logged_in
    expect(page).to have_content("TEST, Nurse")
    expect(page).to have_button("Log out")
  end

  def when_i_click_the_change_role_button
    click_button "Change role"
  end

  def then_i_see_the_organisation_not_found_error
    expect(page).to have_heading(
      "Your organisation is not using this service yet"
    )
  end

  def and_there_is_no_change_role_button
    expect(page).not_to have_button "Change role"
  end

  def then_i_see_the_dashboard
    expect(page).to have_current_path dashboard_path
  end
end
