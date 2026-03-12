# frozen_string_literal: true

describe "Important notices" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  before { given_my_team_exists }

  scenario "Viewing important notices" do
    when_i_go_to_the_imports_page
    then_i_cannot_see_notices

    when_i_go_to_the_notices_page
    then_i_see_permission_denied
  end

  scenario "Deceased notice is created, can be dismissed, and is visible to all teams" do
    given_a_patient_exists_in_multiple_teams

    when_the_patient_is_marked_as_deceased
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_as_superuser
    then_i_see_the_deceased_notice
    and_the_notice_can_be_dismissed

    when_i_start_to_dismiss_the_notice_but_abandon
    then_i_see_the_deceased_notice

    when_i_visit_the_other_team_notices_page
    then_i_see_the_deceased_notice

    when_i_dismiss_the_notice
    then_i_see_no_notices
  end

  scenario "Invalidated notice is created, cannot be dismissed, but resolves when NHS number is added" do
    given_a_patient_exists

    when_the_patient_is_invalidated
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_as_superuser
    then_i_see_the_invalidated_notice
    and_the_notice_cannot_be_dismissed

    when_i_visit_the_edit_patient_page
    and_i_add_an_nhs_number
    and_the_important_notice_job_is_performed
    then_the_patient_is_no_longer_invalidated
    and_i_visit_the_notices_page_as_superuser
    then_i_see_no_notices
  end

  scenario "Restricted notice is created, can be dismissed, and auto-resolves when restriction is lifted" do
    given_a_patient_exists

    when_i_stub_pds_to_return_restricted_patient
    when_pds_updates_the_patient_record
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_as_superuser
    then_i_see_the_restricted_notice
    and_the_notice_can_be_dismissed

    when_pds_updates_patient_as_not_restricted
    when_pds_updates_the_patient_record
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_as_superuser
    then_i_see_no_notices
  end

  scenario "Gillick no notify notice is created and only visible to the vaccinating team" do
    given_a_patient_exists_in_multiple_teams

    when_a_gillick_vaccination_is_recorded
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_as_superuser
    then_i_see_the_gillick_no_notify_notice
    and_the_notice_can_be_dismissed

    when_i_visit_the_other_team_notices_page
    then_i_see_no_notices
  end

  scenario "Team changed notice is created, can be dismissed, and resolves when patient returns to team" do
    and_another_team_exists

    when_i_import_a_patient_into_team_one
    when_i_import_the_same_patient_into_team_two
    and_i_confirm_the_cross_team_school_move_in_team_two
    and_i_visit_the_notices_page_for_team_one_as_superuser
    then_i_see_the_team_changed_notice
    and_the_notice_can_be_dismissed

    when_i_import_the_patient_back_into_team_one
    and_i_confirm_the_school_move_back_to_team_one
    and_the_important_notice_job_is_performed
    and_i_visit_the_notices_page_for_team_one_as_superuser
    then_i_see_no_notices
  end

  scenario "Important notices for patient added to new team" do
    and_another_team_exists
    and_a_patient_with_all_notices_exists
    and_the_important_notice_job_is_performed

    when_the_patient_is_added_to_the_new_team
    and_the_important_notice_job_is_performed
    when_i_go_to_the_imports_page_as_a_superuser_in_the_new_team
    and_i_click_on_notices
    then_i_see_all_patient_notices
    and_i_do_not_see_gillick_no_notify_notices
  end

  def given_my_team_exists
    @programme = Programme.hpv
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @school = create(:school, :secondary, team: @team, urn: "123456")
    @session =
      create(
        :session,
        :unscheduled,
        location: @school,
        team: @team,
        programmes: [@programme]
      )
  end

  def and_another_team_exists
    @other_team = create(:team, :with_one_nurse, programmes: [@programme])
    @other_school =
      create(:school, :secondary, team: @other_team, urn: "111333")
    @other_session =
      create(
        :session,
        :unscheduled,
        location: @other_school,
        team: @other_team,
        programmes: [@programme]
      )
  end

  def given_a_patient_exists
    @patient =
      create(
        :patient,
        session: @session,
        school: @school,
        nhs_number: "9000000009"
      )
  end

  def given_a_patient_exists_in_multiple_teams
    given_a_patient_exists
    and_another_team_exists
    create(:patient_location, patient: @patient, session: @other_session)
  end

  def and_a_patient_with_all_notices_exists
    @patient_all_notices =
      create(
        :patient,
        :deceased,
        :invalidated,
        :restricted,
        session: @session,
        school: @school
      )
    create(
      :vaccination_record,
      notify_parents: false,
      patient: @patient_all_notices,
      programme: @programme,
      session: @session
    )
  end

  def when_the_patient_is_marked_as_deceased
    @patient.update!(
      date_of_death: Date.current,
      date_of_death_recorded_at: Time.current
    )
  end

  def when_the_patient_is_invalidated
    @patient.update!(invalidated_at: Time.current)
  end

  def when_i_stub_pds_to_return_restricted_patient
    stub_pds_get_nhs_number_to_return_a_restricted_patient(@patient.nhs_number)
  end

  def when_pds_updates_the_patient_record
    PatientUpdateFromPDSJob.perform_now(@patient)
  end

  def when_pds_updates_patient_as_not_restricted
    stub_pds_get_nhs_number_to_return_a_patient(@patient.nhs_number)
  end

  def when_a_gillick_vaccination_is_recorded
    create(
      :vaccination_record,
      patient: @patient,
      session: @session,
      programme: @programme,
      notify_parents: false
    )
  end

  def when_i_import_a_patient_into_team_one
    sign_in @team.users.first

    visit "/imports"
    click_button "Upload records"
    choose "Child records"
    click_button "Continue"
    attach_file_fixture "cohort_import[csv]", "cohort_import/valid.csv"
    click_on "Continue"

    wait_for_import_to_complete(CohortImport)

    @patient = Patient.find_by(nhs_number: "9990000018")
  end

  alias_method :when_i_import_the_patient_back_into_team_one,
               :when_i_import_a_patient_into_team_one

  def when_i_import_the_same_patient_into_team_two
    sign_in @other_team.users.first

    visit "/imports"
    click_button "Upload records"
    choose "Child records"
    click_button "Continue"
    attach_file_fixture "cohort_import[csv]",
                        "cohort_import/valid_unknown_school.csv"
    click_on "Continue"

    wait_for_import_to_complete(CohortImport)
  end

  def and_i_confirm_the_cross_team_school_move_in_team_two
    sign_in @other_team.users.first
    visit school_moves_path
    click_on "Review", match: :first

    choose "Update record with new school"
    click_on "Update child record"
  end

  def and_i_confirm_the_school_move_back_to_team_one
    sign_in @team.users.first
    visit school_moves_path
    click_on "Review", match: :first

    choose "Update record with new school"
    click_on "Update child record"
  end

  def and_the_important_notice_job_is_performed
    perform_enqueued_jobs(only: ImportantNoticeGeneratorJob)
  end

  def when_i_visit_the_notices_page_as_superuser
    sign_in @team.users.first, superuser: true
    visit "/imports"
    click_on "Important notices"
  end

  alias_method :and_i_visit_the_notices_page_as_superuser,
               :when_i_visit_the_notices_page_as_superuser

  def when_i_visit_the_other_team_notices_page
    sign_in @other_team.users.first, superuser: true
    visit "/imports"
    click_on "Important notices"
  end

  alias_method :and_i_visit_the_notices_page_for_team_one_as_superuser,
               :when_i_visit_the_notices_page_as_superuser

  def when_i_visit_the_edit_patient_page
    visit edit_patient_path(@patient)
  end

  def and_i_add_an_nhs_number
    click_on "Change NHS number"
    fill_in "What is the child’s NHS number?", with: "975 862 3168"
    click_on "Continue"
  end

  def then_i_see_the_deceased_notice
    expect_notice("Record updated with child’s date of death")
  end

  def then_i_see_the_invalidated_notice
    expect_notice("Record flagged as invalid")
  end

  def then_i_see_the_restricted_notice
    expect_notice("Record flagged as sensitive")
  end

  def then_i_see_the_gillick_no_notify_notice
    expect(page).to have_content("Important notices (1)")
    expect(page).to have_content(@patient.full_name)
    expect(page).to have_content("gave consent")
    expect(page).to have_content("under Gillick competence")
    expect(page).to have_content("does not want their parents to be notified")
  end

  def then_i_see_the_team_changed_notice
    expect_notice("Child has moved to #{@other_team.name} area")
  end

  def when_i_dismiss_the_notice
    click_on "Dismiss"
    click_on "Yes, dismiss this notice"
  end

  def when_i_start_to_dismiss_the_notice_but_abandon
    click_on "Dismiss"
    click_on "No, return to notices"
  end

  def then_i_see_no_notices
    expect(page).to have_content("There are currently no important notices.")
  end

  def and_the_notice_can_be_dismissed
    expect(page).to have_link("Dismiss")
  end

  def and_the_notice_cannot_be_dismissed
    expect(page).not_to have_link("Dismiss")
  end

  def then_the_patient_is_no_longer_invalidated
    expect(@patient.reload).not_to be_invalidated
  end

  def when_the_patient_is_added_to_the_new_team
    SchoolMove.new(
      patient: @patient_all_notices,
      school: @other_school,
      academic_year: AcademicYear.current,
      source: :class_list_import
    ).confirm!

    expect(@patient_all_notices.reload.teams).to include(@other_team)
    expect(@patient_all_notices.reload.teams).to include(@team)
  end

  def when_i_go_to_the_imports_page_as_a_superuser_in_the_new_team
    sign_in @other_team.users.first, superuser: true
    visit "/imports"
  end

  def and_i_click_on_notices
    click_on "Important notices"
  end

  def then_i_see_all_patient_notices
    expect(page).to have_content("Important notices (3)")
    expect(page).to have_content(@patient_all_notices.full_name).at_least(
      3
    ).times
    expect(page).to have_content("Record updated with child’s date of death")
    expect(page).to have_content("Record flagged as invalid")
    expect(page).to have_content("Record flagged as sensitive")
  end

  def and_i_do_not_see_gillick_no_notify_notices
    expect(page).not_to have_content("gave consent")
    expect(page).not_to have_content("under Gillick competence")
  end

  def when_i_go_to_the_imports_page
    sign_in @team.users.first
    visit "/imports"
  end

  def then_i_cannot_see_notices
    expect(page).not_to have_content("Important notices")
  end

  def when_i_go_to_the_notices_page
    visit "/imports/notices"
  end

  def then_i_see_permission_denied
    expect(page).to have_content(
      "You are not authorized to perform this action."
    )
  end

  private

  def expect_notice(content)
    expect(page).to have_content("Important notices (1)")
    expect(page).to have_content(@patient.full_name)
    expect(page).to have_content(content)
  end
end
