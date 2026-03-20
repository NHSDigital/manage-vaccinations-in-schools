# frozen_string_literal: true

describe "MMR triage" do
  around do |example|
    travel_to(Time.zone.local(2024, 10, 1, 9)) { example.run }
  end

  scenario "triage without gelatine only" do
    given_i_am_signed_in_with_mmr_programme
    and_there_is_a_session_today_with_patients_with_consent

    when_i_go_to_the_without_gelatine_only_patient
    then_i_see_the_triage_form

    when_i_record_that_the_patient_is_safe_to_vaccinate(without_gelatine: true)
    and_i_get_confirmation_after_recording

    when_i_go_to_the_activity_log
    then_i_see_the_right_programme_on_the_tab_headings
  end

  scenario "triage without gelatine" do
    given_i_am_signed_in_with_mmr_programme
    and_there_is_a_session_today_with_patients_with_consent

    when_i_go_to_the_without_gelatine_patient
    then_i_see_the_triage_form

    when_i_record_that_the_patient_is_safe_to_vaccinate(without_gelatine: true)
    and_i_get_confirmation_after_recording

    when_i_go_to_the_activity_log
    then_i_see_the_right_programme_on_the_tab_headings
  end

  scenario "triage with gelatine" do
    given_i_am_signed_in_with_mmr_programme
    and_there_is_a_session_today_with_patients_with_consent

    when_i_go_to_the_with_gelatine_patient
    then_i_see_the_triage_form

    when_i_record_that_the_patient_is_safe_to_vaccinate(without_gelatine: false)
    and_i_get_confirmation_after_recording

    when_i_go_to_the_activity_log
    then_i_see_the_right_programme_on_the_tab_headings
  end

  def given_i_am_signed_in_with_mmr_programme
    @programme = Programme.mmr
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @location = create(:gias_school, team: @team)
    @session =
      create(
        :session,
        team: @team,
        programmes: [@programme],
        location: @location
      )
    sign_in @team.users.first
  end

  def and_there_is_a_session_today_with_patients_with_consent
    mmr_variant = Programme::Variant.new(@programme, variant_type: "mmr")

    @without_gelatine_only_patient =
      create(
        :patient,
        :consent_given_without_gelatine_triage_needed,
        :in_attendance,
        session: @session,
        programmes: [mmr_variant]
      )
    @without_gelatine_patient =
      create(
        :patient,
        :consent_given_triage_needed,
        :in_attendance,
        session: @session,
        programmes: [mmr_variant]
      )
    @with_gelatine_patient =
      create(
        :patient,
        :consent_given_triage_needed,
        :in_attendance,
        session: @session,
        programmes: [mmr_variant]
      )
  end

  def when_i_go_to_the_without_gelatine_only_patient
    visit session_patients_path(@session)
    choose "Needs triage"
    @patient = @without_gelatine_only_patient
    click_link @patient.full_name
  end

  def when_i_go_to_the_without_gelatine_patient
    visit session_patients_path(@session)
    choose "Needs triage"
    @patient = @without_gelatine_patient
    click_link @patient.full_name
  end

  def when_i_go_to_the_with_gelatine_patient
    visit session_patients_path(@session)
    choose "Needs triage"
    @patient = @with_gelatine_patient
    click_link @patient.full_name
  end

  def then_i_see_the_triage_form
    expect(page).to have_content("MMR: Needs triage")
  end

  def when_i_record_that_the_patient_is_safe_to_vaccinate(without_gelatine:)
    if without_gelatine
      choose "Yes, it’s safe to vaccinate with the gelatine-free injection"
    else
      choose "Yes, it’s safe to vaccinate"
    end

    click_on "Save triage"
  end

  def and_i_get_confirmation_after_recording
    expect(page).to have_content("MMR: Due 1st dose")
  end

  def when_i_go_to_the_activity_log
    click_on "Session activity and notes"
  end

  def then_i_see_the_right_programme_on_the_tab_headings
    expect(page).not_to have_css(
      "li.app-secondary-navigation__list-item",
      text: "MMRV"
    )
    expect(page).to have_css(
      "li.app-secondary-navigation__list-item",
      text: "MMR"
    )
    expect(page).to have_content("Triaged decision: Safe to vaccinate")
  end
end
