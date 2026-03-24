# frozen_string_literal: true

describe "View children" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before { given_my_team_exists }

  scenario "Viewing children" do
    given_patients_exist
    and_the_patient_is_vaccinated

    when_i_click_on_children
    and_i_filter_for_children
    then_i_see_the_children

    when_i_click_on_a_child
    then_i_see_the_child
    and_i_can_only_see_tabs_for_relevant_programmes

    when_i_click_on_the_flu_tab
    then_i_see_the_childs_flu_vaccinations
    and_i_see_the_childs_flu_sessions
    and_the_flu_tab_is_selected
    and_i_see_the_activity_log_for_flu

    when_i_click_on_the_hpv_tab
    then_i_see_the_childs_hpv_vaccinations
    and_i_see_the_childs_hpv_sessions
    and_the_hpv_tab_is_selected
    and_i_see_the_activity_log_for_hpv
  end

  def given_my_team_exists
    @hpv = Programme.hpv
    @flu = Programme.flu
    @team = create(:team, :with_one_nurse, programmes: [@hpv, @flu])
  end

  def given_patients_exist
    school = create(:school, team: @team)

    @ineligible_school =
      create(
        :school,
        name: "Ineligible School",
        gias_year_groups: [4],
        team: @team
      )

    @new_school = create(:school, name: "New School", team: @team)

    @session =
      create(:session, location: school, team: @team, programmes: [@hpv])

    create(:session, location: @new_school, team: @team, programmes: [@hpv])

    @patient =
      create(
        :patient,
        session: @session,
        given_name: "John",
        family_name: "Smith",
        school:
      )
    create_list(:patient, 9, session: @session)

    another_session = create(:session, team: @team, programmes: [@hpv])

    @existing_patient =
      create(
        :patient,
        session: another_session,
        given_name: "Jane",
        family_name: "Doe"
      )
    create(:vaccination_record, patient: @existing_patient)

    PatientStatusUpdaterJob.perform_inline(@patient.id)
  end

  def and_the_patient_is_vaccinated
    @vaccination_record =
      create(
        :vaccination_record,
        outcome: :administered,
        patient: @patient,
        programme: @hpv,
        session: @session
      )
  end

  def when_i_click_on_children
    sign_in @team.users.first

    visit "/dashboard"
    click_on "Children", match: :first
  end

  def and_i_filter_for_children
    choose "Needs consent"
    click_on "Update results"
  end

  def then_i_see_the_children
    expect(page).to have_content(/\d+ children/)
  end

  def when_i_click_on_a_child
    click_on "SMITH, John"
  end

  def then_i_see_the_child
    expect(page).to have_title("JS")
    expect(page).to have_content("SMITH, John")
    expect(page).to have_content("Sessions")
  end

  def and_i_can_only_see_tabs_for_relevant_programmes
    visible_programmes = @team.programmes.map(&:name)
    visible_programmes.each { |programme| expect(page).to have_link(programme) }

    hidden_programmes = Programme.all.map(&:name) - visible_programmes
    hidden_programmes.each do |programme|
      expect(page).not_to have_link(programme)
    end
  end

  def when_i_click_on_the_flu_tab
    click_on "Flu"
  end

  def then_i_see_the_childs_flu_vaccinations
    expect(page).to have_current_path(patient_programme_path(@patient, "flu"))
    expect(page).to have_css(
      "h3.nhsuk-card__heading",
      text: "No vaccination record"
    )
  end

  def and_the_flu_tab_is_selected
    expect(page).to have_css(".app-secondary-navigation__current", text: "Flu")
  end

  def when_i_click_on_the_hpv_tab
    click_on "HPV"
  end

  def then_i_see_the_childs_hpv_vaccinations
    expect(page).to have_current_path(patient_programme_path(@patient, "hpv"))
    expect(page).to have_css(
      "h3.nhsuk-card__heading",
      text: "Vaccination record"
    )
  end

  def and_the_hpv_tab_is_selected
    expect(page).to have_css(".app-secondary-navigation__current", text: "HPV")
  end

  def and_i_see_the_childs_flu_sessions
    within(".nhsuk-card", text: "Sessions") do
      expect(page).to have_content("No sessions")
    end
  end

  def and_i_see_the_childs_hpv_sessions
    within(".nhsuk-card", text: "Sessions") do
      expect(page).to have_link(
        @session.location.name,
        href: session_patient_programme_path(@session, @patient, "hpv")
      )
      expect(page).to have_content(@session.dates.first.to_fs(:long))
      expect(page).to have_content("Vaccinated")
    end
  end

  def and_i_see_the_activity_log_for_flu
    within(".nhsuk-card", text: "Programme activity") do
      expect(page).to have_content(
        "Added to the session at #{@session.location.name}"
      )
    end
  end

  def and_i_see_the_activity_log_for_hpv
    within(".nhsuk-card", text: "Programme activity") do
      expect(page).to have_content(
        "Vaccinated with #{@vaccination_record.vaccine.brand}"
      )
    end
  end
end
