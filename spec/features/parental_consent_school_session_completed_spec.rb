# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2025, 8, 1)) { example.run } }

  before { stub_pds_search_to_return_no_patients }

  scenario "Move to an unscheduled session" do
    given_an_hpv_programme_is_underway

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    and_i_try_to_give_consent_for_the_unscheduled_school
    then_i_see_that_consent_is_open
  end

  scenario "Move to a completed session" do
    given_an_hpv_programme_is_underway

    when_i_go_to_the_consent_form
    and_i_fill_in_my_childs_name_and_birthday
    and_i_try_to_give_consent_for_the_completed_school
    then_i_see_that_consent_is_closed
  end

  def given_an_hpv_programme_is_underway
    @programme = Programme.hpv
    programmes = [@programme]

    @team = create(:team, :with_one_nurse, programmes:)

    @subteam = create(:subteam, team: @team)

    @unscheduled_school =
      create(
        :gias_school,
        :secondary,
        name: "School 1",
        subteam: @subteam,
        programmes:,
        academic_year: 2024
      )
    @scheduled_school =
      create(
        :gias_school,
        :secondary,
        name: "School 2",
        subteam: @subteam,
        programmes:,
        academic_year: 2024
      )
    @completed_school =
      create(
        :gias_school,
        :secondary,
        name: "School 3",
        subteam: @subteam,
        programmes:,
        academic_year: 2024
      )

    @scheduled_session =
      create(
        :session,
        :scheduled,
        team: @team,
        programmes:,
        location: @scheduled_school
      )

    @unscheduled_session =
      create(
        :session,
        :unscheduled,
        team: @team,
        programmes:,
        location: @unscheduled_school
      )

    @completed_session =
      create(
        :session,
        :completed,
        team: @team,
        programmes:,
        location: @completed_school
      )

    @patient = create(:patient, session: @scheduled_session)
  end

  def when_i_go_to_the_consent_form
    visit start_parent_interface_consent_forms_path(
            @scheduled_session,
            @programme
          )
  end

  def and_i_fill_in_my_childs_name_and_birthday
    click_on "Start now"

    expect(page).to have_content("What is your child’s name?")
    fill_in "First name", with: @patient.given_name
    fill_in "Last name", with: @patient.family_name
    choose "No" # Do they use a different name in school?
    click_on "Continue"

    expect(page).to have_content("What is your child’s date of birth?")
    fill_in "Day", with: @patient.date_of_birth.day
    fill_in "Month", with: @patient.date_of_birth.month
    fill_in "Year", with: @patient.date_of_birth.year
    click_on "Continue"
  end

  def and_i_try_to_give_consent_for_the_unscheduled_school
    choose "No, they go to a different school"
    click_on "Continue"

    select @unscheduled_school.name
    click_on "Continue"
  end

  def and_i_try_to_give_consent_for_the_completed_school
    choose "No, they go to a different school"
    click_on "Continue"

    select @completed_school.name
    click_on "Continue"
  end

  def then_i_see_that_consent_is_open
    expect(page).to have_content("About you")
    expect(page).to have_button("Continue")
  end

  def then_i_see_that_consent_is_closed
    expect(page).to have_content("The deadline for responding has passed")
    expect(page).to have_content(
      "Contact #{@subteam.email} to book a clinic appointment."
    )
  end
end
