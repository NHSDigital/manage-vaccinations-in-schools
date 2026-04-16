# frozen_string_literal: true

describe "Manage teams" do
  scenario "Viewing team settings" do
    given_my_team_exists

    when_i_click_on_team_settings
    then_i_see_the_team_contact_details

    when_i_click_on_clinics
    then_i_see_the_team_clinics

    when_i_click_on_schools
    then_i_see_the_team_schools

    when_i_click_on_sessions
    then_i_see_the_team_sessions
  end

  scenario "Adding a school" do
    given_my_team_exists
    and_other_schools_exist

    when_i_click_on_team_settings
    when_i_click_on_schools
    then_i_see_the_team_schools

    when_i_click_on_add_a_new_school
    then_i_see_the_enter_urn_form

    when_i_enter_a_closed_school_urn
    and_i_continue
    then_i_see_a_closed_school_error

    when_i_enter_a_school_assigned_to_another_team
    and_i_continue
    then_i_see_a_different_team_error

    when_i_enter_a_valid_school_urn
    and_i_continue
    then_i_see_the_confirm_school_screen

    when_i_choose_to_search_again
    and_i_continue
    then_i_see_the_enter_urn_form

    when_i_enter_the_same_school_urn
    and_i_continue
    then_i_see_the_confirm_school_screen

    when_i_confirm_the_school
    and_i_continue
    then_i_see_the_year_groups_screen
    and_year_groups_are_pre_selected

    when_i_add_more_year_groups
    and_i_continue
    then_i_see_the_check_and_confirm_screen_for_school

    when_i_confirm_add_school
    then_i_see_the_school_confirmation_banner
    and_the_school_is_added_to_my_team
    and_the_school_has_the_correct_year_groups
  end

  scenario "Adding a school site" do
    given_my_team_exists

    when_i_click_on_team_settings
    when_i_click_on_schools
    then_i_see_the_team_schools

    when_i_click_on_add_a_new_school_site
    then_i_see_the_select_school_site_form
    and_i_do_not_see_schools_from_previous_year_in_the_dropdown

    when_i_select_a_school
    and_i_continue
    then_i_see_the_school_site_details_form

    when_i_fill_in_the_school_site_details
    and_i_continue
    then_i_see_the_year_groups_screen
    and_year_groups_are_pre_selected

    when_i_add_more_year_groups
    and_i_continue
    then_i_see_the_check_and_confirm_screen

    when_i_confirm
    then_i_see_the_school_site_confirmation_banner
    and_a_school_site_is_created
    and_the_school_site_has_the_correct_year_groups

    when_i_go_back
    then_i_am_redirected_to_the_schools_list
  end

  scenario "Editing a school site" do
    given_my_team_exists
    and_sites_exist

    when_i_click_on_team_settings
    when_i_click_on_schools
    then_i_see_the_team_schools
    and_all_schools_have_edit_links

    when_i_click_on_edit_a_school_site
    then_i_see_the_school_summary_with_edit_links

    when_i_click_on_change_name
    and_i_fill_in_the_new_name_with_same_value_as_another_site
    then_i_see_a_name_validation_error

    when_i_fill_in_the_new_name
    and_i_continue
    then_i_see_the_name_is_updated

    when_i_click_on_change_address
    and_i_fill_in_the_new_address
    and_i_continue
    then_i_see_the_address_is_updated

    when_i_click_on_change_year_groups
    when_i_try_to_remove_a_year_group
    and_i_continue
    then_i_see_a_year_groups_removal_error

    and_i_restore_the_year_group
    and_i_fill_in_the_new_year_groups
    and_i_continue
    then_i_see_the_year_groups_are_updated

    when_i_click_save_changes
    then_i_see_the_team_schools
    and_the_site_details_are_updated
  end

  scenario "Editing a school" do
    given_my_team_exists

    when_i_click_on_team_settings
    when_i_click_on_schools
    then_i_see_the_team_schools

    when_i_click_on_edit_a_school
    then_i_see_the_school_summary_with_only_year_groups_link

    when_i_click_on_change_year_groups
    when_i_try_to_remove_a_year_group
    and_i_continue
    then_i_see_a_year_groups_removal_error

    and_i_restore_the_year_group
    and_i_fill_in_the_new_year_groups
    and_i_continue
    then_i_see_the_year_groups_are_updated

    when_i_click_save_changes
    then_i_see_the_team_schools
    and_the_school_year_groups_are_updated
  end

  def given_my_team_exists
    @team = create(:team, :with_one_nurse)
    @school =
      create(:gias_school, team: @team, urn: "12345", name: "Current school")
    @school_last_year =
      create(:gias_school, urn: "67890", name: "School last year")
    @school_last_year.attach_to_team!(
      @team,
      academic_year: AcademicYear.pending - 1
    )
    create(:gias_school, team: @team, urn: "34567")
    create(:community_clinic, team: @team)
  end

  def and_sites_exist
    @school.update!(site: "A")

    @site_b =
      create(
        :gias_school,
        team: @team,
        urn: @school.urn,
        site: "B",
        name: "Site B"
      )
  end

  def when_i_click_on_team_settings
    sign_in @team.users.first

    visit "/dashboard"
    click_on "Your team", match: :first
  end

  def then_i_see_the_team_contact_details
    expect(page).to have_content("Contact details")
  end

  def when_i_click_on_clinics
    click_on "Clinics"
  end

  def then_i_see_the_team_clinics
    expect(page).to have_content("Clinics")
    expect(page).to have_content(@team.community_clinics.first.name)
    expect(page).to have_content(@team.community_clinics.first.address_line_1)
  end

  def when_i_click_on_schools
    find(".app-sub-navigation__link", text: "Schools").click
  end

  def then_i_see_the_team_schools
    expect(page).to have_content("Schools")
    expect(page).to have_content(@school.name)
    expect(page).to have_content(@school.address_line_1)
    expect(page).not_to have_content(@school_last_year.urn)
  end

  alias_method :then_i_am_redirected_to_the_schools_list,
               :then_i_see_the_team_schools

  def and_all_schools_have_edit_links
    expect(page).to have_link("Edit", href: edit_team_school_path("34567"))
    expect(page).to have_link("Edit", href: edit_team_school_path("12345A"))
    expect(page).to have_link("Edit", href: edit_team_school_path("12345B"))
  end

  def when_i_click_on_edit_a_school_site
    within("tr", text: "Site B") { click_on "Edit" }
  end

  def when_i_click_on_edit_a_school
    within("tr", text: @school.name) { click_on "Edit" }
  end

  def then_i_see_the_school_summary_with_edit_links
    expect(page).to have_content("Site B")
    expect(page).to have_link("Change", text: /name/i)
    expect(page).to have_link("Change", text: /address/i)
    expect(page).to have_link("Change", text: /year groups/i)
  end

  def then_i_see_the_school_summary_with_only_year_groups_link
    expect(page).to have_content(@school.name)
    expect(page).to have_link("Change", text: /year groups/i)
    expect(page).not_to have_link("Change", text: /name/i)
    expect(page).not_to have_link("Change", text: /address/i)
  end

  def when_i_click_on_change_name
    click_on "Change name"
  end

  def and_i_fill_in_the_new_name_with_same_value_as_another_site
    fill_in "Name", with: @school.name
    click_on "Continue"
  end

  def then_i_see_a_name_validation_error
    expect(page).to have_content("This site name is already in use")
  end

  def when_i_fill_in_the_new_name
    fill_in "Name", with: "Updated Site B Name"
  end

  def then_i_see_the_name_is_updated
    expect(page).to have_content("Updated Site B Name")
  end

  def when_i_click_on_change_address
    click_on "Change address"
  end

  def and_i_fill_in_the_new_address
    fill_in "Address line 1", with: "456 New Street"
    fill_in "Address line 2", with: "Floor 2"
    fill_in "Town", with: "New Town"
    fill_in "Postcode", with: "SW1A 2AA"
  end

  def then_i_see_the_address_is_updated
    expect(page).to have_content("456 New Street")
    expect(page).to have_content("New Town")
    expect(page).to have_content("SW1A 2AA")
  end

  def when_i_click_on_change_year_groups
    click_on "Change year groups"
  end

  def and_i_fill_in_the_new_year_groups
    check "Year 12"
  end

  def when_i_try_to_remove_a_year_group
    uncheck "Year 8"
  end

  def then_i_see_a_year_groups_removal_error
    expect(page).to have_content(
      "You cannot remove a year group from the school once it has been added"
    )
  end

  def and_i_restore_the_year_group
    check "Year 8"
  end

  def then_i_see_the_year_groups_are_updated
    expect(page).to have_content("years 1 to 12")
  end

  def when_i_click_continue
    click_on "Continue"
  end

  def when_i_click_save_changes
    click_on "Save changes"
  end

  def and_the_site_details_are_updated
    @site_b.reload
    expect(@site_b.name).to eq("Updated Site B Name")
    expect(@site_b.address_line_1).to eq("456 New Street")
    expect(@site_b.address_line_2).to eq("Floor 2")
    expect(@site_b.address_town).to eq("New Town")
    expect(@site_b.address_postcode).to eq("SW1A 2AA")
    expect(@site_b.location_year_groups.pluck(:value)).to include(12)
  end

  def and_the_school_year_groups_are_updated
    @school.reload
    expect(@school.location_year_groups.pluck(:value)).to include(12)
  end

  def when_i_click_on_sessions
    find(".app-sub-navigation__link", text: "Sessions").click
  end

  def then_i_see_the_team_sessions
    expect(page).to have_content("Session defaults")
  end

  def when_i_click_on_add_a_new_school_site
    click_on "Add a new school site"
  end

  def then_i_see_the_select_school_site_form
    expect(page).to have_content("Which school do you want to add a site to?")
  end

  alias_method :then_i_am_redirected_to_the_start_of_the_wizard,
               :then_i_see_the_select_school_site_form

  def and_i_do_not_see_schools_from_previous_year_in_the_dropdown
    expect(page).not_to have_select(
      "draft-school-site-urn-field",
      with_options: [@school_last_year.name]
    )
  end

  def when_i_select_a_school
    select @school.name
  end

  def and_i_continue
    click_on "Continue"
  end

  alias_method :when_i_continue, :and_i_continue

  def then_i_see_the_school_site_details_form
    expect(page).to have_content("Site details")
  end

  def when_i_fill_in_the_school_site_details
    fill_in "Name", with: "New School Site"
    fill_in "Address line 1", with: "123 Main St"
    fill_in "Address line 2", with: "Suite 100"
    fill_in "Town", with: "Anytown"
    fill_in "Postcode", with: "SW1A 1AA"
  end

  def then_i_see_the_year_groups_screen
    expect(page).to have_content("Year groups")
  end

  def and_year_groups_are_pre_selected
    expect(find_field("Year 8")).to be_checked
  end

  def when_i_add_more_year_groups
    check "Year 12"
  end

  def then_i_see_the_check_and_confirm_screen
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("12345B")
    expect(page).to have_content("Year groups")
    expect(page).to have_content("years 1 to 12")
  end

  def when_i_confirm
    click_on "Add site"
  end

  def then_i_see_the_school_site_confirmation_banner
    expect(page).to have_content("New School Site has been added to your team.")
  end

  def and_a_school_site_is_created
    expect(Location.gias_school.count).to eq(4)

    site = Location.gias_school.last
    expect(site.name).to eq("New School Site")
    expect(site.address_line_1).to eq("123 Main St")
    expect(site.address_line_2).to eq("Suite 100")
    expect(site.address_town).to eq("Anytown")
    expect(site.address_postcode).to eq("SW1A 1AA")
    expect(site.urn).to eq("12345")
    expect(site.site).to eq("B")
    expect(site.teams).to include(@team)
  end

  def and_the_school_site_has_the_correct_year_groups
    site = Location.gias_school.last
    expect(site.location_year_groups.pluck(:value)).to include(12)
  end

  def when_i_go_back
    visit draft_school_path("confirm")
  end

  def and_other_schools_exist
    @closed_school =
      create(:gias_school, :closed, urn: "99999", name: "Closed school")
    @other_team = create(:team)
    @other_team_school =
      create(
        :gias_school,
        urn: "88888",
        team: @other_team,
        name: "Other Team School"
      )
    @available_school =
      create(:gias_school, urn: "77777", name: "Available School")
  end

  def when_i_click_on_add_a_new_school
    click_on "Add a new school"
  end

  def then_i_see_the_enter_urn_form
    expect(page).to have_content("Find a school to add to your team")
    expect(page).to have_field("School URN")
  end

  def when_i_enter_a_closed_school_urn
    fill_in "School URN", with: @closed_school.urn
  end

  def then_i_see_a_closed_school_error
    expect(page).to have_content(
      "This school is closed and cannot be added to your team."
    )
  end

  def when_i_enter_a_school_assigned_to_another_team
    fill_in "School URN", with: @other_team_school.urn
  end

  def then_i_see_a_different_team_error
    expect(page).to have_content(
      "This school is already assigned to another team"
    )
  end

  def when_i_enter_a_valid_school_urn
    fill_in "School URN", with: @available_school.urn
  end

  alias_method :when_i_enter_the_same_school_urn,
               :when_i_enter_a_valid_school_urn

  def then_i_see_the_confirm_school_screen
    expect(page).to have_content("Confirm school")
    expect(page).to have_content(@available_school.name)
    expect(page).to have_content("Is this the correct school?")
  end

  def when_i_choose_to_search_again
    choose "No, search again"
  end

  def when_i_confirm_the_school
    choose "Yes, add this school"
  end

  def then_i_see_the_check_and_confirm_screen_for_school
    expect(page).to have_content("Check and confirm")
    expect(page).to have_content("School details")
    expect(page).to have_content(@available_school.name)
    expect(page).to have_content(@available_school.urn)
    expect(page).to have_content("Year groups")
    expect(page).to have_content("years 1 to 12")
  end

  def when_i_confirm_add_school
    click_on "Add school"
  end

  def then_i_see_the_school_confirmation_banner
    expect(page).to have_content(
      "#{@available_school.name} has been added to your team."
    )
  end

  def and_the_school_is_added_to_my_team
    @available_school.reload
    expect(@available_school.teams).to include(@team)
  end

  def and_the_school_has_the_correct_year_groups
    @available_school.reload
    expect(@available_school.location_year_groups.pluck(:value)).to include(12)
  end
end
