# frozen_string_literal: true

describe "Tallying on session overview page" do
  scenario "confirming the numbers and visiting the filters" do
    given_a_session_for_flu_is_running_today
    and_there_is_five_children_eligible_for_vaccination
    and_one_has_no_response
    and_one_has_given_consent_for_nasal_spray
    and_one_has_given_consent_for_injection
    and_one_could_not_be_vaccinated
    and_one_vaccinated
    and_i_visit_the_session_record_tab
    then_i_see_the_correct_tallies_corresponding_to_the_current_state

    when_i_click_on_each_tally_the_filters_match_the_same_count
  end

  def given_a_session_for_flu_is_running_today
    @flu_programme = Programme.flu
    programmes = [@flu_programme]
    team = create(:team, :with_one_nurse, programmes:)

    @session =
      create(:session, :today, :requires_no_registration, programmes:, team:)

    sign_in team.users.first
  end

  def and_i_visit_the_session_record_tab
    visit session_path(@session, tallying: true)
  end

  alias_method :when_i_visit_the_session_record_tab,
               :and_i_visit_the_session_record_tab

  def and_there_is_five_children_eligible_for_vaccination
    @patients = create_list(:patient, 5, session: @session, year_group: 9)
  end

  def and_one_has_no_response
    create(
      :patient_programme_status,
      :needs_consent_no_response,
      patient: @patients.first,
      programme: @flu_programme
    )
  end

  def and_one_has_given_consent_for_nasal_spray
    create(
      :patient_programme_status,
      :due_nasal,
      patient: @patients.second,
      programme: @flu_programme
    )
  end

  def and_one_has_given_consent_for_injection
    create(
      :patient_programme_status,
      :due_injection_without_gelatine,
      patient: @patients.third,
      programme: @flu_programme
    )
  end

  def and_one_could_not_be_vaccinated
    create(
      :patient_programme_status,
      :has_refusal_consent_refused,
      patient: @patients.fourth,
      programme: @flu_programme
    )
  end

  def and_one_vaccinated
    create(
      :patient_programme_status,
      :vaccinated_fully,
      patient: @patients.fifth,
      programme: @flu_programme,
      location: @session.location
    )
  end

  def then_i_see_the_correct_tallies_corresponding_to_the_current_state
    within(".nhsuk-card", text: "Needs consent") do
      expect(page).to have_content(1)
    end

    within(".nhsuk-card", text: "Due nasal spray") do
      expect(page).to have_content(1)
    end

    within(".nhsuk-card", text: "Due injection") do
      expect(page).to have_content(1)
    end

    within(".nhsuk-card", text: "Has a refusal") do
      expect(page).to have_content(1)
    end

    within(".nhsuk-card", text: "Vaccinated") do
      expect(page).to have_content(1)
    end
  end

  def when_i_click_on_each_tally_the_filters_match_the_same_count
    click_link "Needs consent"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patients.first.given_name)

    and_i_visit_the_session_record_tab

    click_link "Due nasal spray"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patients.second.given_name)

    and_i_visit_the_session_record_tab

    click_link "Due injection"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patients.third.given_name)

    and_i_visit_the_session_record_tab

    click_link "Has a refusal"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patients.fourth.given_name)

    and_i_visit_the_session_record_tab

    click_link "Vaccinated"
    expect(page).to have_content("Showing 1 to 1 of 1 children")
    expect(page).to have_content(@patients.fifth.given_name)
  end
end
