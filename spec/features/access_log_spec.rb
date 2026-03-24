# frozen_string_literal: true

describe "Access log" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before { given_i_am_signed_in }

  scenario "View patient" do
    when_i_go_to_the_children
    and_i_filter_for_year_8
    and_i_go_to_a_patient
    then_i_am_recorded_in_the_access_log(controller: "patients")
  end

  scenario "View patient's programme" do
    when_i_go_to_the_children
    and_i_filter_for_year_8
    and_i_go_to_a_patient
    and_i_click_on_a_programme
    then_i_am_recorded_in_the_access_log(controller: "patients_programmes")
  end

  scenario "View patient in a session" do
    when_i_go_to_the_session
    and_i_go_to_a_patient
    then_i_am_recorded_in_the_access_log(controller: "patient_sessions")
  end

  scenario "View patient's activity log in a session" do
    when_i_go_to_the_session
    and_i_go_to_a_patient
    and_i_click_on_session_activity_and_notes
    then_i_am_recorded_in_the_access_log_twice(controller: "patient_sessions")
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    team = create(:team, :with_one_nurse, programmes:)

    @user = team.users.first

    @session = create(:session, team:, programmes:)

    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        year_group: 8,
        session: @session
      )

    sign_in @user
  end

  def when_i_go_to_the_children
    visit dashboard_path
    click_on "Children", match: :first
  end

  def and_i_filter_for_year_8
    check "Year 8"
    click_button "Update results"
  end

  def when_i_go_to_the_session
    visit sessions_path
    click_on @session.location.name
    within(".app-secondary-navigation") { click_on "Children" }
  end

  def and_i_go_to_a_patient
    click_on @patient.full_name
  end

  def and_i_click_on_a_programme
    within(".app-secondary-navigation") { click_on "HPV" }
  end

  def and_i_click_on_session_activity_and_notes
    click_on "Session activity and notes"
  end

  def then_i_am_recorded_in_the_access_log(controller:)
    access_log_entries = AccessLogEntry.where(controller:)

    expect(access_log_entries.count).to eq(1)
    expect(access_log_entries.first).to have_attributes(
      user: @user,
      controller:,
      action: "show"
    )
  end

  def then_i_am_recorded_in_the_access_log_twice(controller:)
    access_log_entries = AccessLogEntry.where(controller:)

    expect(access_log_entries.count).to eq(2)
    expect(access_log_entries.first).to have_attributes(
      user: @user,
      controller:,
      action: "show"
    )
    expect(access_log_entries.second).to have_attributes(
      user: @user,
      controller:,
      action: "log"
    )
  end
end
