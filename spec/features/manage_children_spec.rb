# frozen_string_literal: true

describe "Manage children" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before { given_my_team_exists }

  scenario "viewing children" do
    given_patients_exist
    and_the_patient_is_vaccinated

    when_i_click_on_children
    then_i_see_no_children_by_default

    when_i_filter_for_children
    then_i_see_the_children

    when_i_click_on_a_child
    then_i_see_the_child
  end

  scenario "viewing children paginated" do
    given_many_patients_exist

    when_i_click_on_children
    and_i_filter_for_children
    then_i_see_the_children
    and_i_see_the_pages

    when_i_visit_an_overflow_page
    then_i_see_the_last_page
  end

  scenario "viewing children who have aged out" do
    given_patients_exist
    and_todays_date_is_in_the_far_future

    when_i_click_on_children
    and_i_filter_for_children
    then_i_see_no_children

    when_i_click_on_view_aged_out_children
    then_i_see_the_children
  end

  scenario "adding an NHS number" do
    given_patients_exist
    and_sync_vaccination_records_to_nhs_feature_is_enabled
    and_the_patient_is_vaccinated

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    then_i_see_the_child

    when_i_click_on_edit_child_record
    then_i_see_the_edit_child_record_page

    when_i_click_on_change_nhs_number
    then_i_see_the_edit_nhs_number_page

    when_i_enter_an_nhs_number
    then_i_see_the_edit_child_record_page
    and_i_see_the_nhs_number

    when_i_wait_for_the_sync_to_complete
    then_the_vaccination_record_is_created_with_the_nhs

    when_i_click_on_change_nhs_number
    and_i_enter_an_existing_nhs_number
    then_i_see_the_merge_record_page

    when_i_click_on_merge_records
    then_i_see_the_merged_edit_child_record_page
    and_the_vaccination_record_is_updated_with_the_nhs

    when_i_go_back_to_the_patient_page
    and_i_click_on_a_programme
    then_i_see_the_patient_merge_in_the_activity_log
  end

  scenario "adding an NHS number to an invalidated patient" do
    given_an_invalidated_patient_exists

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    then_i_see_the_child

    when_i_click_on_edit_child_record
    then_i_see_the_edit_child_record_page

    when_i_click_on_change_nhs_number
    then_i_see_the_edit_nhs_number_page

    when_i_enter_an_nhs_number
    then_i_see_the_edit_child_record_page
    and_i_see_the_nhs_number
    and_the_patient_is_no_longer_invalidated
    and_the_important_notice_is_dismissed
  end

  scenario "inviting to community clinic" do
    given_patients_exist
    and_a_clinic_session_exists

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    and_i_click_on_a_programme
    and_i_dont_see_a_community_clinic_session

    when_i_click_on_invite_to_clinic
    then_i_see_a_success_banner
    and_i_see_a_community_clinic_session
    and_i_dont_see_an_invite_to_clinic_button

    when_i_click_on_children
    and_i_check_invited_to_clinic
    then_i_see_the_child_has_been_invited
  end

  scenario "Removing an NHS number" do
    given_patients_exist
    and_sync_vaccination_records_to_nhs_feature_is_enabled
    and_the_patient_is_vaccinated
    and_the_vaccination_has_been_synced_to_nhs

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    then_i_see_the_child

    when_i_click_on_edit_child_record
    then_i_see_the_edit_child_record_page

    when_i_click_on_change_nhs_number
    then_i_see_the_edit_nhs_number_page

    when_i_enter_a_blank_nhs_number
    then_i_see_the_edit_child_record_page
    and_i_see_the_blank_nhs_number
    and_the_vaccination_record_is_updated_with_the_nhs
  end

  scenario "Editing school" do
    given_patients_exist

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    then_i_see_the_child

    when_i_click_on_edit_child_record
    then_i_see_the_edit_child_record_page

    when_i_click_on_change_school
    then_i_see_the_edit_school_page
    and_i_should_not_see_ineligible_school

    when_i_choose_a_school
    then_i_see_the_edit_child_record_page
    and_i_see_the_school_has_been_updated

    when_i_click_on_change_school
    then_i_see_the_edit_school_page

    when_i_choose_home_schooled
    then_i_see_the_edit_child_record_page
    and_i_see_the_child_is_home_schooled
  end

  scenario "Adding a parent" do
    given_patients_exist

    when_i_click_on_children
    and_i_filter_for_children
    and_i_click_on_a_child
    then_i_see_the_child

    when_i_click_on_edit_child_record
    then_i_see_the_edit_child_record_page

    when_i_click_on_add_new_parent
    then_i_see_the_new_parent_page

    when_i_fill_in_parent_details
    and_i_save_the_parent
    then_i_should_see_a_validation_error

    when_i_choose_the_parent_relationship
    and_i_save_the_parent
    then_i_see_the_new_parent_is_created
  end

  scenario "Edit child ethnicity information" do
    given_patients_exist
    and_i_am_on_the_child_edit_page
    when_i_click_on_change_ethnicity
    and_i_choose_another_ethnic_group
    and_i_choose_another_ethnic_background
    then_the_ethnicity_is_changed
  end

  def given_my_team_exists
    @flu = Programme.flu
    @hpv = Programme.hpv
    @team =
      create(
        :team,
        :with_generic_clinic,
        :with_one_nurse,
        programmes: [@flu, @hpv]
      )
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

    @new_session =
      create(:session, location: @new_school, team: @team, programmes: [@hpv])

    parent = create(:parent)
    @patient =
      create(
        :patient,
        session: @session,
        given_name: "John",
        family_name: "Smith",
        parents: [parent],
        school:
      )
    create(:vaccination_record, patient: @patient, programme: @hpv)
    create_list(:patient, 9, session: @session)

    another_session = create(:session, team: @team, programmes: [@hpv])

    @existing_patient =
      create(
        :patient,
        session: another_session,
        given_name: "Jane",
        family_name: "Doe"
      )
    @current_ethnic_group = @patient.ethnic_group
    @current_ethnic_background = @patient.ethnic_background

    create(:vaccination_record, patient: @existing_patient)

    PatientStatusUpdater.call
  end

  def and_a_clinic_session_exists
    create(
      :session,
      location: @team.generic_clinic,
      team: @team,
      programmes: @team.programmes
    )
  end

  def given_many_patients_exist
    @session = create(:session, team: @team, programmes: [@hpv])

    create_list(:patient, 100, session: @session)

    PatientStatusUpdater.call
  end

  def given_an_invalidated_patient_exists
    session = create(:session, team: @team, programmes: [@hpv])

    @patient =
      create(
        :patient,
        :invalidated,
        session:,
        given_name: "John",
        family_name: "Smith"
      )

    create(:patient, session:, nhs_number: nil)

    PatientStatusUpdater.call
  end

  def and_the_patient_is_vaccinated
    create(
      :vaccination_record,
      patient: @patient,
      programme: @hpv,
      session: @session
    )
  end

  def and_sync_vaccination_records_to_nhs_feature_is_enabled
    Flipper.enable(:imms_api_sync_job, @hpv)
    Flipper.enable(:imms_api_integration)

    immunisation_uuid = Random.uuid
    @stubbed_post_request = stub_immunisations_api_post(uuid: immunisation_uuid)
    @stubbed_put_request = stub_immunisations_api_put(uuid: immunisation_uuid)
    @stubbed_delete_request =
      stub_immunisations_api_delete(uuid: immunisation_uuid)
  end

  def and_the_vaccination_has_been_synced_to_nhs
    Sidekiq::Job.drain_all
  end

  def and_todays_date_is_in_the_far_future
    travel 13.years
  end

  def when_i_click_on_children
    sign_in @team.users.first

    visit "/dashboard"
    click_on "Children", match: :first
  end

  def then_i_see_no_children_by_default
    expect(page).to have_content(
      "Search for a child or use filters to see children matching your selection."
    )
  end

  def when_i_filter_for_children
    choose "Needs consent"
    click_on "Update results"
  end

  alias_method :and_i_filter_for_children, :when_i_filter_for_children

  def and_i_check_invited_to_clinic
    check "Invited to clinic"
    click_on "Update results"
  end

  def then_i_see_the_children
    expect(page).to have_content(/\d+ children/)
  end

  def then_i_see_no_children
    expect(page).to have_content("No children")
  end

  def and_i_see_the_pages
    expect(page).to have_content("Next page")
    expect(page).to have_content("Showing 1 to 50 of 100 children")
  end

  def when_i_visit_an_overflow_page
    click_on "2"
  end

  def then_i_see_the_last_page
    expect(page).to have_content("Previous page")
    expect(page).to have_content("Showing 51 to 100 of 100 children")
  end

  def when_i_click_on_view_aged_out_children
    find(".nhsuk-details__summary").click
    choose "Any"
    check "Children aged out of programmes"
    click_on "Update results"
  end

  def when_i_click_on_a_child
    click_on "SMITH, John"
  end

  alias_method :and_i_click_on_a_child, :when_i_click_on_a_child

  def and_i_click_on_a_programme
    click_on "Flu", match: :first
  end

  def then_i_see_the_child
    expect(page).to have_title("JS")
    expect(page).to have_content("SMITH, John")
    expect(page).to have_content("Sessions")
  end

  def then_i_see_the_child_has_been_invited
    expect(page).to have_content("SMITH, John")
    expect(page).to have_content("Clinic invitationsFlu")
  end

  def when_i_click_on_edit_child_record
    click_on "Edit child record"
  end

  def then_i_see_the_edit_child_record_page
    expect(page).to have_title("Edit child record")
    expect(page).to have_content("SMITH, John")
    expect(page).to have_content("Change")
  end

  def when_i_click_on_change_nhs_number
    click_on "Change NHS number"
  end

  def when_i_click_on_change_ethnicity
    click_on "Change Ethnicity"
  end

  def when_i_click_on_change_school
    click_on "Change School"
  end

  def then_i_see_the_edit_nhs_number_page
    expect(page).to have_content("What is the child’s NHS number?")
  end

  def then_i_see_the_edit_school_page
    expect(page).to have_content("What school does the child go to?")
  end

  def when_i_enter_an_nhs_number
    fill_in "What is the child’s NHS number?", with: "975 862 3168"
    click_on "Continue"
  end

  def when_i_enter_a_blank_nhs_number
    travel 1.minute
    fill_in "What is the child’s NHS number?", with: ""
    click_on "Continue"
  end

  def and_i_enter_an_existing_nhs_number
    fill_in "What is the child’s NHS number?",
            with: @existing_patient.nhs_number
    click_on "Continue"
  end

  def and_i_should_not_see_ineligible_school
    expect(page).not_to have_select(
      "What school does the child go to?",
      with_options: ["Ineligible School"]
    )
  end

  def when_i_choose_a_school
    select "New School", from: "What school does the child go to?"
    click_on "Continue"
  end

  def when_i_choose_home_schooled
    select "Home-schooled", from: "What school does the child go to?"
    click_on "Continue"
  end

  def and_i_see_the_nhs_number
    expect(page).to have_content("975 862 3168")
  end

  def when_i_click_on_add_new_parent
    click_on "Add parent or guardian"
  end

  def then_i_see_the_new_parent_page
    expect(page).to have_content("Add parent or guardian")
  end

  def when_i_fill_in_parent_details
    fill_in "Name", with: "Lucille Bluth"
    fill_in "Phone number", with: "01234 567890"
    fill_in "Email address", with: "lucille@bluth.com"
    choose "They do not have specific needs"
  end

  def and_i_save_the_parent
    click_on "Save"
  end

  def then_i_should_see_a_validation_error
    expect(page).to have_content("There is a problem")
    expect(page).to have_content("Choose a relationship")
  end

  def when_i_choose_the_parent_relationship
    choose "Mum"
  end

  def then_i_see_the_new_parent_is_created
    expect(page).to have_content("Edit child record")
    expect(page).to have_content("Lucille Bluth (mum)")
    expect(@patient.parents.count).to eq(2)
  end

  def and_the_patient_is_no_longer_invalidated
    expect(@patient.reload).not_to be_invalidated
  end

  def and_i_see_the_school_has_been_updated
    expect(page).to have_content("New School")
    expect(@patient.reload.school).to eq(@new_school)
    expect(@patient.sessions).to contain_exactly(@new_session)
    expect(
      @patient.school_move_log_entries.pluck(:school_id)
    ).to contain_exactly(@new_school.id)
  end

  def and_i_see_the_child_is_home_schooled
    expect(page).to have_content("Home-schooled")
    expect(@patient.reload.home_educated).to be true
    expect(@patient.school).to be_nil
    expect(@patient.home_educated).to be true
  end

  def and_the_important_notice_is_dismissed
    notice = @patient.important_notices.find_by(type: :invalidated)
    perform_enqueued_jobs_while_exists(only: ImportantNoticeGeneratorJob)
    expect(notice.reload.dismissed_at).to be_present
  end

  def and_i_see_the_blank_nhs_number
    expect(page).to have_content("NHS numberNot provided")
  end

  def then_i_see_the_merge_record_page
    expect(page).to have_content("Do you want to merge this record?")
    expect(page).to have_content("DOE, Jane")
  end

  def when_i_click_on_merge_records
    travel 1.minute
    click_on "Merge records"
  end

  def then_i_see_the_merged_edit_child_record_page
    expect(page).to have_title("Edit child record")
    expect(page).to have_content("DOE, Jane")
  end

  def and_i_see_the_cohort
    expect(page).not_to have_content("No cohorts")
    expect(page).not_to have_content("No sessions")
  end

  def and_i_dont_see_a_community_clinic_session
    expect(page).not_to have_content("Community clinic")
  end

  def when_i_click_on_invite_to_clinic
    click_on "Invite to community clinic"
  end

  def then_i_see_a_success_banner
    expect(page).to have_content("invited to the clinic")
  end

  def and_i_see_a_community_clinic_session
    expect(page).to have_content("Community clinic")
  end

  def and_i_dont_see_an_invite_to_clinic_button
    expect(page).not_to have_button("Invite to community clinic")
  end

  def when_i_go_to_the_dashboard
    sign_in @team.users.first

    visit "/dashboard"
  end

  def when_i_wait_for_the_sync_to_complete
    Sidekiq::Job.drain_all
  end

  def then_the_vaccination_record_is_created_with_the_nhs
    expect(@stubbed_post_request).to have_been_requested
  end

  def and_the_vaccination_record_is_updated_with_the_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_put_request).to have_been_requested
  end

  def and_the_vaccination_record_is_deleted_from_the_nhs
    Sidekiq::Job.drain_all
    expect(@stubbed_delete_request).to have_been_requested
  end

  def and_i_am_on_the_child_edit_page
    sign_in @team.users.first
    visit edit_patient_path(@patient)
  end

  def and_i_choose_another_ethnic_group
    @new_ethnic_group =
      choose_different_radio(field_name: "patient[ethnic_group]")
    click_on "Continue"
  end

  def and_i_choose_another_ethnic_background
    @new_ethnic_background =
      choose_different_radio(field_name: "patient[ethnic_background]")
    click_on "Continue"
  end

  def choose_different_radio(field_name:)
    radios =
      page.all("input[name='#{field_name}'][type='radio']", visible: :all)
    currently_checked_value = radios.find(&:checked?)&.value
    candidate = radios.find { it.value != currently_checked_value }
    candidate.choose
    candidate.value
  end

  def then_the_ethnicity_is_changed
    ethnic_group_text = I18n.t("ethnicity.groups.#{@new_ethnic_group}")
    ethnic_background_text =
      I18n.t("ethnicity.backgrounds.#{@new_ethnic_background}")
    expect(page).to have_content(
      "#{ethnic_group_text} (#{ethnic_background_text})"
    )
  end

  def when_i_go_back_to_the_patient_page
    visit patient_path(@existing_patient)
  end

  def then_i_see_the_patient_merge_in_the_activity_log
    expect(page).to have_content("Child record merged")
    expect(page).to have_content(
      "The record for SMITH, John (date of birth #{@patient.date_of_birth.to_fs(:long)}) was merged with " \
        "the record for DOE, Jane (date of birth #{@existing_patient.date_of_birth.to_fs(:long)}) because " \
        "they have the same NHS number (#{@existing_patient.nhs_number})."
    )
  end
end
