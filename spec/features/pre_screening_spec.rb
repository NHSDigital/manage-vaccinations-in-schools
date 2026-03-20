# frozen_string_literal: true

describe "Pre-screening" do
  around { |example| travel_to(Time.zone.local(2024, 2, 1)) { example.run } }

  scenario "must be confirmed before vaccinating HPV" do
    given_a_session_exists(Programme.hpv)

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    then_i_see_the_pre_screening_questions
    and_i_dont_see_the_medication_question
    and_i_dont_see_the_pregnancy_question
    and_i_record_vaccination_without_pre_screening_checks
    then_i_see_an_error_message
  end

  scenario "must be confirmed before vaccinating MenACWY" do
    given_a_session_exists(Programme.menacwy)

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    then_i_see_the_pre_screening_questions
    and_i_see_the_medication_question
    and_i_dont_see_the_pregnancy_question
    and_i_dont_see_the_asthma_flare_up_question
    and_i_record_vaccination_without_pre_screening_checks
    then_i_see_an_error_message
  end

  scenario "must be confirmed before vaccinating Td/IPV" do
    given_a_session_exists(Programme.td_ipv)

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    then_i_see_the_pre_screening_questions
    and_i_see_the_medication_question
    and_i_see_the_pregnancy_question
    and_i_dont_see_the_asthma_flare_up_question
    and_i_record_vaccination_without_pre_screening_checks
    then_i_see_an_error_message
  end

  scenario "must be confirmed before vaccinating flu injection" do
    given_a_session_exists(Programme.flu)

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    then_i_see_the_pre_screening_questions
    and_i_see_the_medication_question
    and_i_dont_see_the_asthma_flare_up_question
    and_i_dont_see_the_pregnancy_question
    and_i_record_vaccination_without_pre_screening_checks
    then_i_see_an_error_message
  end

  scenario "must be confirmed before vaccinating flu nasal" do
    given_a_session_exists(Programme.flu, vaccine_method: "nasal")

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    then_i_see_the_pre_screening_questions
    and_i_see_the_medication_question
    and_i_see_the_asthma_flare_up_question
    and_i_dont_see_the_pregnancy_question
    and_i_record_vaccination_without_pre_screening_checks
    then_i_see_an_error_message
  end

  def given_a_session_exists(programme, vaccine_method: "injection")
    team = create(:team, programmes: [programme])

    @nurse = create(:nurse, teams: [team])

    @session =
      create(
        :session,
        team:,
        programmes: [programme],
        location: create(:gias_school, team:)
      )

    @patient =
      if vaccine_method == "nasal"
        create(
          :patient,
          :consent_given_nasal_only_triage_not_needed,
          :in_attendance,
          session: @session
        )
      else
        create(
          :patient,
          :consent_given_triage_not_needed,
          :in_attendance,
          session: @session
        )
      end
  end

  def when_i_go_to_a_patient_that_is_safe_to_vaccinate
    sign_in @nurse
    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_the_pre_screening_questions
    expect(page).to have_content("is not acutely unwell")
    expect(page).to have_content(
      "knows what the vaccination is for, and agrees to have it"
    )
    expect(page).to have_content(
      "has no other contraindications which prevent vaccination"
    )
  end

  def and_i_see_the_medication_question
    expect(page).to have_content(
      "is not taking any medication which prevents vaccination"
    )
  end

  def and_i_dont_see_the_medication_question
    expect(page).not_to have_content(
      "is not taking any medication which prevents vaccination"
    )
  end

  def and_i_see_the_asthma_flare_up_question
    expect(page).to have_content(
      "if they have asthma, has not had a flare-up of symptoms in the past 72 hours, " \
        "including wheezing or needing to use a reliever inhaler more than usual"
    )
  end

  def and_i_dont_see_the_asthma_flare_up_question
    expect(page).not_to have_content(
      "if they have asthma, has not had a flare-up of symptoms in the past 72 hours, " \
        "including wheezing or needing to use a reliever inhaler more than usual"
    )
  end

  def and_i_see_the_pregnancy_question
    expect(page).to have_content("is not pregnant")
  end

  def and_i_dont_see_the_pregnancy_question
    expect(page).not_to have_content("is not pregnant")
  end

  def and_i_record_vaccination_without_pre_screening_checks
    within all("form")[2] do
      within all("fieldset")[2] do
        choose "Yes"
        if has_field?("Left arm (upper position)", wait: 0)
          choose("Left arm (upper position)")
        end
      end
      click_button "Continue"
    end
  end

  def then_i_see_an_error_message
    expect(page).to have_content(
      "Confirm you’ve checked the pre-screening statements are true"
    )
  end
end
