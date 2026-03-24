# frozen_string_literal: true

describe "Import class lists - Moving patients" do
  around { |example| travel_to(Date.new(2023, 5, 20)) { example.run } }

  scenario "User uploads a file and moves patients to a new session" do
    given_an_hpv_programme_is_underway

    when_i_visit_a_school_page_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    then_i_should_see_the_import_page

    when_i_upload_a_valid_file
    then_i_should_see_the_import_complete_page

    when_i_visit_a_different_school_page_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    and_i_upload_a_valid_file
    then_i_should_see_the_import_complete_page

    when_i_visit_the_school_moves
    then_i_should_see_the_school_moves

    when_i_confirm_a_move
    then_i_should_see_a_success_flash

    when_i_ignore_a_move
    then_i_should_see_a_notice_flash
  end

  scenario "User uploads a file and moves patients to a new session from a different team" do
    given_an_hpv_programme_is_underway

    when_i_visit_a_school_page_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    then_i_should_see_the_import_page

    when_i_upload_a_valid_file
    then_i_should_see_the_import_complete_page

    when_i_visit_a_different_school_page_from_the_second_team_for_the_hpv_programme
    and_i_start_adding_children_to_the_school
    and_i_select_the_year_groups
    and_i_upload_a_valid_file
    then_i_should_see_the_import_complete_page

    when_i_visit_the_school_moves_for_the_second_team
    then_i_should_see_the_school_moves

    when_i_see_the_school_moves_from_the_first_team
    then_i_should_not_see_the_school_moves

    when_i_visit_the_school_moves_for_the_second_team
    and_i_confirm_a_move
    then_i_should_see_a_success_flash
    and_the_patient_should_be_in_the_right_teams
    and_i_should_see_an_important_notice_for_patient_moved_out_of_the_first_team

    when_i_visit_the_school_moves_for_the_second_team
    and_i_ignore_a_move
    then_i_should_see_a_notice_flash
  end

  context "when PDS lookup during import is enabled" do
    scenario "User uploads a file and moves patients to a new session" do
      given_an_hpv_programme_is_underway
      and_pds_lookup_during_import_is_enabled

      when_i_visit_a_school_page_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      then_i_should_see_the_import_page

      when_i_upload_a_valid_file
      then_i_should_see_the_import_complete_page

      when_i_visit_a_different_school_page_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      and_i_upload_a_valid_file
      then_i_should_see_the_import_complete_page

      when_i_visit_the_school_moves
      then_i_should_see_the_school_moves

      when_i_confirm_a_move
      then_i_should_see_a_success_flash

      when_i_ignore_a_move
      then_i_should_see_a_notice_flash
    end

    scenario "User uploads a file and moves patients to a new session from a different team" do
      given_an_hpv_programme_is_underway
      and_pds_lookup_during_import_is_enabled

      when_i_visit_a_school_page_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      then_i_should_see_the_import_page

      when_i_upload_a_valid_file
      then_i_should_see_the_import_complete_page

      when_i_visit_a_different_school_page_from_the_second_team_for_the_hpv_programme
      and_i_start_adding_children_to_the_school
      and_i_select_the_year_groups
      and_i_upload_a_valid_file(review: true)
      then_i_should_see_the_import_review_page_with_school_moves

      when_i_approve_the_import_review
      then_i_should_see_the_import_complete_page

      when_i_visit_the_school_moves_for_the_second_team
      then_i_should_see_the_school_moves

      when_i_see_the_school_moves_from_the_first_team
      then_i_should_not_see_the_school_moves

      when_i_visit_the_school_moves_for_the_second_team
      and_i_confirm_a_move
      then_i_should_see_a_success_flash
      and_the_patient_should_be_in_the_right_teams
      and_i_should_see_an_important_notice_for_patient_moved_out_of_the_first_team

      when_i_visit_the_school_moves_for_the_second_team
      and_i_ignore_a_move
      then_i_should_see_a_notice_flash
    end
  end

  def given_an_hpv_programme_is_underway
    programmes = [Programme.hpv]

    @team = create(:team, :with_one_nurse, programmes:)
    @user = @team.users.first

    @second_team = create(:team, :with_one_nurse, programmes:)
    @second_user = @second_team.users.first

    location = create(:school, :secondary, name: "Waterloo Road", team: @team)
    other_location =
      create(:school, :secondary, name: "Different Road", team: @team)

    second_team_location =
      create(
        :school,
        :secondary,
        name: "Second Team School",
        team: @second_team
      )
    create(
      :session,
      :unscheduled,
      team: @second_team,
      location: second_team_location,
      programmes:
    )

    create(:session, :unscheduled, team: @team, location:, programmes:)
    create(
      :session,
      :unscheduled,
      team: @team,
      location: other_location,
      programmes:
    )
  end

  def and_pds_lookup_during_import_is_enabled
    Flipper.enable(:import_search_pds)

    stub_pds_search_to_return_a_patient(
      "9990000026",
      "family" => "Smith",
      "given" => "Jimmy",
      "birthdate" => "eq2010-01-02",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9999075320",
      "family" => "Clarke",
      "given" => "Jennifer",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9999075320",
      "family" => "Clarke",
      "given" => "Jennifer",
      "birthdate" => "eq2010-01-01",
      "address-postalcode" => "SW1A 1AB"
    )

    stub_pds_search_to_return_a_patient(
      "9435764479",
      "family" => "Doe",
      "given" => "Mark",
      "birthdate" => "eq2010-01-03",
      "address-postalcode" => "SW1A 1AA"
    )

    stub_pds_search_to_return_a_patient(
      "9435764479",
      "family" => "Doe",
      "given" => "Michel",
      "birthdate" => "eq2010-01-03",
      "address-postalcode" => "SW1A 1AA"
    )
  end

  def when_i_visit_a_school_page_for_the_hpv_programme
    sign_in @user
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Waterloo Road"
  end

  def when_i_visit_a_different_school_page_for_the_hpv_programme
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Different Road"
  end

  def when_i_visit_a_different_school_page_from_the_second_team_for_the_hpv_programme
    sign_in @second_user
    visit "/team"
    visit "/dashboard"
    click_on "Schools", match: :first
    click_on "Second Team School"
  end

  def and_i_start_adding_children_to_the_school
    click_on "Import class lists"
  end

  def and_i_select_the_year_groups
    check "Year 8"
    check "Year 9"
    check "Year 10"
    check "Year 11"
    click_on "Continue"
  end

  def then_i_should_see_the_import_page
    expect(page).to have_content("Upload class list")
  end

  def when_i_upload_a_valid_file(review: false)
    attach_file_fixture "class_import[csv]", "class_import/valid.csv"
    click_on "Continue"
    if review
      wait_for_import_to_complete_until_review(ClassImport)
    else
      wait_for_import_to_complete(ClassImport)
    end
  end

  alias_method :and_i_upload_a_valid_file, :when_i_upload_a_valid_file

  def then_i_should_see_the_import_review_page_with_school_moves
    page.refresh
    expect(page).to have_content("Review and approve")
    find(
      ".nhsuk-details__summary-text",
      text: "4 school moves across teams"
    ).click
    expect(page).to have_content("This child is moving in from")
  end

  def when_i_approve_the_import_review
    click_on "Approve and import records"
    wait_for_import_to_commit(ClassImport)
  end

  def then_i_should_see_the_import_complete_page
    expect(page).to have_content("Completed")
    expect(page).to have_content("Uploaded by")
  end

  def when_i_visit_the_school_moves
    click_on "School moves"
  end

  def when_i_visit_the_school_moves_for_the_second_team
    sign_in @second_user
    visit "/school-moves"
  end

  def when_i_see_the_school_moves_from_the_first_team
    sign_in @user
    visit "/school-moves"
  end

  def then_i_should_see_the_school_moves
    expect(page).to have_content("School moves (4)")
    expect(page).to have_content("4 school moves")
  end

  def then_i_should_not_see_the_school_moves
    expect(page).to have_content("School moves (0)")
    expect(page).to have_content("There are currently no school moves.")
  end

  def when_i_confirm_a_move
    click_on "Review", match: :first
    choose "Update record with new school"
    click_on "Update child record"
  end

  alias_method :and_i_confirm_a_move, :when_i_confirm_a_move

  def then_i_should_see_a_success_flash
    expect(page).to have_alert("Success")
  end

  def when_i_ignore_a_move
    click_on "Review", match: :first
    choose "Ignore new information"
    click_on "Update child record"
  end

  alias_method :and_i_ignore_a_move, :when_i_ignore_a_move

  def then_i_should_see_a_notice_flash
    expect(page).to have_region("Information")
  end

  def and_the_patient_should_be_in_the_right_teams
    patient = Patient.select { it.archive_reasons.count > 0 }.sole
    expect(patient.teams).to contain_exactly(@team, @second_team)
    expect(patient.archive_reasons.sole.team_id).to eq(@team.id)
    expect(patient.archive_reasons.sole.type).to eq("moved_out_of_area")
  end

  def and_i_should_see_an_important_notice_for_patient_moved_out_of_the_first_team
    sign_in @user, superuser: true
    visit "/imports/notices"
    expect(page).to have_content("Child has moved to #{@second_team.name} area")
  end
end
