# frozen_string_literal: true

describe "Archive children" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before do
    given_an_team_exists
    and_i_am_signed_in
  end

  scenario "View archived patients" do
    given_an_unarchived_patient_exists
    and_an_archived_patient_exists

    when_i_visit_the_children_page
    and_i_filter_for_the_child
    then_i_see_only_the_unarchived_patient

    when_i_filter_to_see_only_archived_patients
    then_i_see_only_the_archived_patient
  end

  scenario "Return to child record" do
    given_an_unarchived_patient_exists

    when_i_visit_the_unarchived_patient
    and_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_click_back
    then_i_see_the_unarchived_patient_page

    when_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_click_return_to_child_record
    then_i_see_the_unarchived_patient_page
  end

  scenario "Mark as duplicate" do
    given_an_unarchived_patient_exists
    and_a_duplicate_patient_exists

    when_i_visit_the_unarchived_patient
    and_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_choose_the_duplicate_reason
    and_i_fill_in_the_nhs_number
    and_i_click_on_archive_record
    then_i_see_the_duplicate_patient_page
    and_i_see_a_success_message

    when_i_visit_the_children_page
    and_i_filter_for_the_duplicate_patient
    then_i_see_only_the_duplicate_patient
  end

  scenario "Mark as imported in error" do
    given_an_unarchived_patient_exists

    when_i_visit_the_unarchived_patient
    and_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_choose_the_imported_in_error_reason
    and_i_click_on_archive_record
    then_i_see_the_unarchived_patient_page
    and_i_see_a_success_message
    and_i_see_an_archived_tag
    and_i_see_an_activity_log_entry

    when_i_visit_the_children_page
    and_i_filter_to_see_only_archived_patients
    then_i_see_only_the_unarchived_patient
  end

  scenario "Mark as moved out of the area" do
    given_an_unarchived_patient_exists

    when_i_visit_the_unarchived_patient
    and_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_choose_the_moved_out_of_area_reason
    and_i_click_on_archive_record
    then_i_see_the_unarchived_patient_page
    and_i_see_a_success_message
    and_i_see_an_archived_tag
    and_i_see_an_activity_log_entry

    when_i_visit_the_children_page
    and_i_filter_to_see_only_archived_patients
    then_i_see_only_the_unarchived_patient
  end

  scenario "For other reason" do
    given_an_unarchived_patient_exists

    when_i_visit_the_unarchived_patient
    and_i_click_on_archive_record
    then_i_see_the_archive_page

    when_i_choose_the_other_reason
    and_i_fill_in_more_details
    and_i_click_on_archive_record
    then_i_see_the_unarchived_patient_page
    and_i_see_a_success_message
    and_i_see_an_activity_log_entry

    when_i_visit_the_children_page
    and_i_filter_to_see_only_archived_patients
    then_i_see_only_the_unarchived_patient
  end

  def given_an_team_exists
    hpv = Programme.hpv
    flu = Programme.flu
    programmes = [hpv, flu]
    @team = create(:team, programmes:)

    @session = create(:session, team: @team, programmes: [flu])
  end

  def and_i_am_signed_in
    @user = create(:nurse, team: @team)
    sign_in @user
  end

  def given_an_unarchived_patient_exists
    @unarchived_patient = create(:patient, session: @session, nhs_number: nil)
  end

  def and_an_archived_patient_exists
    @archived_patient = create(:patient)
    create(
      :archive_reason,
      :imported_in_error,
      patient: @archived_patient,
      team: @team
    )
  end

  def and_a_duplicate_patient_exists
    @duplicate_patient = create(:patient, session: @session)
  end

  def when_i_visit_the_children_page
    visit patients_path
  end

  def and_i_filter_for_the_child
    fill_in "Search", with: @unarchived_patient.full_name
    click_button "Update results"
  end

  def then_i_see_only_the_unarchived_patient
    expect(page).to have_content("1 child")
    expect(page).to have_content(@unarchived_patient.full_name)
  end

  def when_i_filter_to_see_only_archived_patients
    fill_in "Search", with: ""
    find(".nhsuk-details__summary").click
    check "Archived records"
    click_on "Search"
  end

  alias_method :and_i_filter_to_see_only_archived_patients,
               :when_i_filter_to_see_only_archived_patients

  def then_i_see_only_the_archived_patient
    expect(page).to have_content("1 child")
    expect(page).to have_content(@archived_patient.full_name)
  end

  def when_i_visit_the_unarchived_patient
    visit patient_path(@unarchived_patient)
  end

  def when_i_click_on_archive_record
    click_on "Archive"
  end

  alias_method :and_i_click_on_archive_record, :when_i_click_on_archive_record

  def then_i_see_the_archive_page
    expect(page).to have_content("Why do you want to archive this record?")
  end

  def when_i_click_back
    click_on "Back"
  end

  def when_i_click_return_to_child_record
    click_on "Return to child record"
  end

  def then_i_see_the_unarchived_patient_page
    expect(page).to have_content("Child record")
    expect(page).to have_content(@unarchived_patient.full_name)
  end

  def when_i_choose_the_duplicate_reason
    choose "It’s a duplicate"
  end

  def and_i_fill_in_the_nhs_number
    fill_in "Enter the NHS number for the duplicate record",
            with: @duplicate_patient.nhs_number
  end

  def then_i_see_the_duplicate_patient_page
    expect(page).to have_content("Child record")
    expect(page).to have_content(@duplicate_patient.full_name)
  end

  def and_i_see_a_success_message
    expect(page).to have_content("This record has been archived")
  end

  def and_i_see_an_archived_tag
    expect(page).to have_content("Archived")
  end

  def and_i_see_an_activity_log_entry
    expect(page).to have_content("Record archived:")
  end

  def and_i_filter_for_the_duplicate_patient
    fill_in "Search", with: @duplicate_patient.full_name
    click_on "Update results"
  end

  def then_i_see_only_the_duplicate_patient
    expect(page).to have_content("1 child")
    expect(page).to have_content(@duplicate_patient.full_name)
  end

  def when_i_choose_the_imported_in_error_reason
    choose "It was imported in error"
  end

  def when_i_choose_the_moved_out_of_area_reason
    choose "The child has moved out of the area"
  end

  def when_i_choose_the_other_reason
    choose "Other"
  end

  def and_i_fill_in_more_details
    fill_in "Give details", with: "A different reason."
  end
end
