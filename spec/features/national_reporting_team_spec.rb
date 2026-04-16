# frozen_string_literal: true

describe "National reporting team homepage and navigation" do
  scenario "Homepage shows national reporting title and cards" do
    given_i_am_signed_in_as_an_national_reporting_team
    when_i_visit_the_dashboard
    then_i_should_see_the_national_reporting_cards
    and_i_should_see_the_import_records_card
    and_i_should_see_the_children_card
    and_i_should_see_the_national_reporting_service_name
    and_i_should_see_the_national_reporting_service_guide_link
  end

  scenario "Navigation shows only import and children tabs" do
    given_i_am_signed_in_as_an_national_reporting_team
    when_i_visit_the_dashboard
    then_i_should_see_only_import_and_children_navigation_items
    and_there_should_be_no_count_next_to_the_import_link
  end

  scenario "Children page search shows limited filters and the patient's card" do
    given_i_am_signed_in_as_an_national_reporting_team
    and_i_upload_a_valid_file
    when_i_visit_the_children_page
    then_i_should_see_limited_filters

    and_i_search_for_a_child(search_term: "Harry")
    then_i_should_see_the_childs_card
  end

  scenario "Child record page shows vaccination records first and cannot be archived" do
    given_i_am_signed_in_as_an_national_reporting_team
    and_i_upload_a_valid_file
    when_i_visit_the_children_page
    and_i_search_for_a_child(search_term: "Harry")
    and_i_click_on_the_childs_card(given_name: "Harry", family_name: "Potter")
    then_i_should_see_vaccinations_then_child_details
    and_child_can_be_edited_but_not_be_archived
    and_child_does_not_look_archived
  end

  scenario "Parent details are not shown for a child with parents" do
    given_i_am_signed_in_as_an_national_reporting_team
    and_there_is_a_child_with_parents
    when_i_visit_the_children_page
    and_i_search_for_a_child(search_term: "Draco")
    and_i_click_on_the_childs_card(given_name: "Draco", family_name: "Malfoy")
    then_i_should_not_see_parent_details

    when_i_edit_the_child_record
    then_i_should_not_see_parent_details
    and_i_should_not_see_add_parent_button
  end

  def given_i_am_signed_in_as_an_national_reporting_team
    @team =
      create(
        :team,
        :national_reporting,
        :with_one_admin,
        programmes: [Programme.flu, Programme.hpv],
        ods_code: "XX99"
      )
    @school = create(:gias_school, team: @team, urn: 100_000)
    sign_in @team.users.first
  end

  def and_there_is_a_child_with_parents
    @child_with_parents =
      create(:patient, given_name: "Draco", family_name: "Malfoy", team: @team)
    create(
      :parent_relationship,
      patient: @child_with_parents,
      parent: create(:parent)
    )
    # Create a vaccination record to link this patient with the team
    create(
      :vaccination_record,
      programme: Programme.flu,
      patient: @child_with_parents,
      session: create(:session, team: @team, location: @school),
      team: @team
    )
  end

  def when_i_visit_the_dashboard
    visit dashboard_path
  end

  def then_i_should_see_the_national_reporting_cards
    cards = page.all(".nhsuk-card-group__item")
    expect(cards.count).to eq(3)
  end

  def and_i_should_see_the_import_records_card
    cards = page.all(".nhsuk-card-group__item")
    card = cards[0]

    expect(card).to have_css("h2", text: "Imports")
    expect(card).to have_link("Imports", href: imports_path)
  end

  def and_i_should_see_the_children_card
    cards = page.all(".nhsuk-card-group__item")
    card = cards[1]

    expect(card).to have_css("h2", text: "Children")
    expect(card).to have_link("Children", href: patients_path)
  end

  def then_i_should_see_only_import_and_children_navigation_items
    navigation_items = page.all(".nhsuk-header__navigation-item")
    expect(navigation_items.count).to eq(2)
    expect(navigation_items[0]).to have_link("Imports", href: imports_path)
    expect(navigation_items[1]).to have_link("Children", href: patients_path)
  end

  def and_there_should_be_no_count_next_to_the_import_link
    expect(page).not_to have_css(".app-count", text: "(0)")
  end

  def when_i_visit_the_children_page
    visit patients_path
  end

  def then_i_should_see_limited_filters
    expect(page).to have_content(
      "Search for a child or use filters to see children matching your selection."
    )

    # Open the advanced filters details element
    find("summary", text: "Advanced filters").click

    form_groups = page.all(".nhsuk-form-group")
    expect(form_groups.count).to eq(7)
    expect(form_groups[0]).to have_content("Search")
    expect(form_groups[1]).to have_content("Year group")
    expect(form_groups[2]).to have_content("Date of birth")
    # form groups 3, 4 and 5 are form groups within the date of birth form group
    expect(form_groups[6]).to have_content("Children missing an NHS number")
  end

  def and_i_should_see_the_national_reporting_service_name
    page_title = page.first("h1")
    service_name = page.first(".nhsuk-header__service-name")
    expect(page_title.text).to eq(
      "Manage vaccinations in schools (Mavis) National reporting"
    )
    expect(service_name.text).to eq(
      "Manage vaccinations in schoolsNational reporting"
    )
  end

  def and_i_upload_a_valid_file
    visit imports_path
    click_on "Upload records"
    attach_file_fixture "immunisation_import[csv]",
                        "immunisation_import/national_reporting/valid_mixed_flu_hpv.csv"
    click_on "Continue"
    wait_for_import_to_complete(ImmunisationImport)
    expect(page).to have_content("2 imported records")
  end

  def and_i_search_for_a_child(search_term:)
    fill_in "Search", with: search_term
    click_on "Search"
  end
  alias_method :when_i_search_for_a_child, :and_i_search_for_a_child

  def and_i_click_on_the_childs_card(given_name:, family_name:)
    click_on "#{family_name.upcase}, #{given_name}"
  end

  def then_i_should_see_the_childs_card
    expect(page).to have_content("POTTER, Harry")
    expect(page).to have_content("1 January 2001")
    expect(page).to have_content(
      "Programme status\nFluVaccinatedVaccinated on 9 November 2025"
    )
    expect(page).not_to have_content("HPV")
  end

  def then_i_should_see_vaccinations_then_child_details
    app_cards = page.all(".app-card")
    expect(app_cards.count).to eq(2)
    expect(app_cards[0]).to have_content("Vaccinations")
    expect(app_cards[1]).to have_content("Child record")
  end

  def and_child_can_be_edited_but_not_be_archived
    app_card_buttons = page.all(".nhsuk-card .nhsuk-card__action")
    expect(app_card_buttons.count).to eq(1)
    expect(page).to have_css(
      ".nhsuk-card .nhsuk-card__action",
      text: "Edit child record"
    )
    expect(page).not_to have_content("Archive child record")
  end

  def and_child_does_not_look_archived
    expect(page).not_to have_content("Archived")
  end

  def when_i_edit_the_child_record
    click_on "Edit child record"
  end

  def then_i_should_not_see_parent_details
    expect(page).not_to have_content("First parent or guardian")
  end

  def and_i_should_not_see_add_parent_button
    expect(page).not_to have_content("Add parent or guardian")
  end

  def and_i_should_see_the_national_reporting_service_guide_link
    expect(page).to have_link(
      "Service guidance",
      href:
        "https://guide.manage-vaccinations-in-schools.nhs.uk/national-reporting/"
    )
  end
end
