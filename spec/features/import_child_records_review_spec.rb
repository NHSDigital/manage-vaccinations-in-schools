# frozen_string_literal: true

describe "Import child records review" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  scenario "Skips moving child from another team to unknown school" do
    given_i_am_signed_in
    and_two_teams_exist
    and_a_patient_exists_in_another_teams_school

    when_i_visit_the_import_page
    and_i_choose_to_import_child_records
    and_i_upload_a_file_moving_child_to_unknown_school
    then_i_should_see_the_import_review_page
    and_i_should_see_the_skipped_school_moves_summary

    when_i_approve_the_import
    then_the_import_should_be_complete
    and_i_should_see_the_skipped_school_moves_summary
    and_the_patient_should_remain_at_their_current_school
    and_the_patient_should_not_be_linked_to_my_team
    and_the_patient_should_not_be_linked_to_the_import
    and_the_import_changes_should_not_be_processed
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv, Programme.menacwy, Programme.td_ipv]
    @team = create(:team, :with_one_nurse, programmes:)
    @user = @team.users.first

    # Create a school in this team (children can be uploaded here)
    create(:school, urn: "123456", team: @team)

    sign_in @user
  end

  def and_two_teams_exist
    programmes = [Programme.hpv, Programme.menacwy, Programme.td_ipv]
    @other_team =
      create(:team, :with_one_nurse, programmes:, name: "Other Team")
    @other_school =
      create(
        :school,
        urn: "111222",
        name: "Other Team School",
        team: @other_team
      )
  end

  def and_a_patient_exists_in_another_teams_school
    @patient =
      create(
        :patient,
        given_name: "Mark",
        family_name: "Doe",
        nhs_number: nil,
        date_of_birth: Date.new(2010, 1, 3),
        address_postcode: "SW1A 1AA",
        school: @other_school
      )
  end

  def when_i_visit_the_import_page
    visit "/dashboard"
    click_on "Import", match: :first
  end

  def and_i_choose_to_import_child_records
    click_on "Upload records"
    choose "Child records"
    click_on "Continue"
  end

  def and_i_upload_a_file_moving_child_to_unknown_school
    attach_file_fixture "cohort_import[csv]",
                        "cohort_import/valid_unknown_school.csv"
    click_on "Continue"
    wait_for_import_to_complete_until_review(CohortImport)
  end

  def then_i_should_see_the_import_review_page
    page.refresh
    click_on_most_recent_import(CohortImport)
    expect(page).to have_content("Review and approve")
  end

  def and_i_should_see_the_skipped_school_moves_summary
    expect(page).to have_content("1 record not imported")
    expect(page).to have_content("at their current school")
  end

  def when_i_approve_the_import
    click_on "Approve and import records"
    wait_for_import_to_commit(CohortImport)
  end

  def then_the_import_should_be_complete
    expect(page).to have_content("Completed")
  end

  def and_the_patient_should_remain_at_their_current_school
    @patient.reload
    expect(@patient.school).to eq(@other_school)
  end

  def and_the_patient_should_not_be_linked_to_my_team
    expect(@patient.teams).not_to include(@team)
    expect(@patient.teams).to contain_exactly(@other_team)
  end

  def and_the_patient_should_not_be_linked_to_the_import
    expect(@patient.cohort_imports).to be_empty
  end

  def and_the_import_changes_should_not_be_processed
    expect(@patient.parents).to be_empty
  end
end
