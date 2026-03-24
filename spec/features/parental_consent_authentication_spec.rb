# frozen_string_literal: true

describe "Parental consent" do
  scenario "Authentication" do
    given_an_hpv_programme_is_underway
    when_i_go_to_the_consent_form
    then_i_see_the_start_page

    when_i_fill_in_my_childs_name_and_birthday
    then_i_see_the_first_school_page

    when_i_go_to_the_consent_form
    then_i_see_the_start_page

    when_i_fill_in_my_childs_name_and_birthday
    then_i_see_the_second_school_page

    when_i_go_to_the_first_consent_form_school_page
    then_i_see_the_start_page
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    location =
      create(:gias_school, name: "Pilot School", programmes: [@programme])
    @session = create(:session, :scheduled, programmes: [@programme], location:)
    @child = create(:patient, session: @session)
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(@session, @programme)
  end

  def then_i_see_the_start_page
    expect(page).to have_content("Give or refuse consent for vaccinations")
  end

  def when_i_fill_in_my_childs_name_and_birthday
    click_on "Start now"

    expect(page).to have_content("What is your child’s name?")
    fill_in "First name", with: @child.given_name
    fill_in "Last name", with: @child.family_name
    choose "No" # Do they use a different name in school?
    click_on "Continue"

    expect(page).to have_content("What is your child’s date of birth?")
    fill_in "Day", with: @child.date_of_birth.day
    fill_in "Month", with: @child.date_of_birth.month
    fill_in "Year", with: @child.date_of_birth.year
    click_on "Continue"
  end

  def then_i_see_the_first_school_page
    expect(page).to have_content("Confirm your child’s school")
    @school_page_url = page.current_url
  end

  def then_i_see_the_second_school_page
    expect(page).to have_content("Confirm your child’s school")
  end

  def when_i_go_to_the_first_consent_form_school_page
    visit @school_page_url
  end
end
