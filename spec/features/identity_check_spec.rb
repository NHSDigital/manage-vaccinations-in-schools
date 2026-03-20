# frozen_string_literal: true

describe "HPV vaccination identity check" do
  before { Flipper.enable(:ops_tools) }

  scenario "Default identification, changed and edited" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_record_a_vaccination_was_given
    then_i_see_the_check_and_confirm_page
    and_child_identified_by_shows_the_child

    when_i_click_change_identifier
    and_i_select_identity_confirmed_by_someone_else_but_leave_fields_blank
    and_i_click_continue
    then_i_see_errors_about_missing_person_name_and_relationship

    and_i_confirm_the_patient_identity_was_confirmed_by_someone_else
    and_i_return_to_the_confirmation_page
    then_i_see_that_child_identified_by_shows_the_person_and_relationship

    when_i_click_change_identifier
    and_i_confirm_the_patient_identity_was_confirmed_by_child
    and_i_return_to_the_confirmation_page
    and_i_confirm_the_details

    when_i_go_to_the_vaccination_record
    then_i_see_that_child_identified_by_shows_the_child

    when_i_edit_the_vaccination_record
    when_i_click_change_identifier
    and_i_select_identity_confirmed_by_someone_else_but_leave_fields_blank
    and_i_click_continue
    then_i_see_errors_about_missing_person_name_and_relationship

    and_i_confirm_the_patient_identity_was_confirmed_by_someone_else
    and_i_save_the_changes
    when_i_go_to_the_vaccination_record
    then_i_see_that_child_identified_by_shows_the_person_and_relationship
  end

  scenario "Non-vaccination identified by child" do
    given_i_am_signed_in

    when_i_go_to_a_patient_that_is_safe_to_vaccinate
    and_i_record_that_the_patient_was_unwell
    and_i_confirm_the_details

    when_i_go_to_the_vaccination_record
    then_i_see_that_child_identified_by_shows_the_child
  end

  private

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)

    location = create(:gias_school, team: @team)
    @batch =
      create(
        :batch,
        :not_expired,
        team: @team,
        vaccine: programmes.first.vaccines.active.first
      )
    @session = create(:session, team: @team, programmes:, location:)
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )

    sign_in @team.users.first
  end

  def when_i_go_to_a_patient_that_is_safe_to_vaccinate
    visit session_record_path(@session)
    click_link @patient.full_name
  end

  def and_i_confirm_the_patient_identity_was_confirmed_by_child
    choose "The child"
    click_button "Continue"
  end

  def and_i_confirm_the_patient_identity_was_confirmed_by_someone_else
    if page.has_content?("No, it was confirmed by somebody else")
      choose "No, it was confirmed by somebody else"
    else
      choose "Someone else"
    end
    fill_in "What is the person’s name?", with: "Sadie Smith"
    fill_in "What is their relationship to the child", with: "teacher"
    click_button "Continue"
  end

  def and_i_record_a_vaccination_was_given
    within all("form")[2] do
      within all("fieldset")[1] do
        check "I have checked that the above statements are true"
      end

      within all("fieldset")[2] do
        choose "Yes"
        choose "Left arm (upper position)"
      end

      click_button "Continue"
    end

    choose @batch.number
    click_button "Continue"
  end

  def and_i_record_that_the_patient_was_unwell
    within all("form")[2] do
      within all("fieldset")[2] do
        choose "No"
      end

      click_button "Continue"
    end

    choose "They were not well enough"
    click_button "Continue"
  end

  def and_i_confirm_the_details
    click_button "Confirm"
  end

  def when_i_go_to_the_vaccination_record
    click_on Date.current.to_fs(:long)
  end

  def when_i_click_change_identifier
    click_on "Change child identified by"
  end

  def and_i_return_to_the_confirmation_page
    5.times { click_on "Continue" }
  end

  def and_i_click_continue
    click_button "Continue"
  end

  alias_method :when_i_click_continue, :and_i_click_continue

  def and_i_select_identity_confirmed_by_someone_else_but_leave_fields_blank
    if page.has_content?("No, it was confirmed by somebody else")
      choose "No, it was confirmed by somebody else"
    else
      choose "Someone else"
    end
  end

  def then_i_see_errors_about_missing_person_name_and_relationship
    expect(page).to have_content("Enter the person’s name")
    expect(page).to have_content("Enter the person’s relationship")
  end

  def then_i_see_that_child_identified_by_shows_the_child
    expect(page).to have_content("Child identified by")
    expect(page).to have_content("The child")
  end
  alias_method :and_child_identified_by_shows_the_child,
               :then_i_see_that_child_identified_by_shows_the_child

  def then_i_see_that_child_identified_by_shows_the_person_and_relationship
    expect(page).to have_content("Child identified by")
    expect(page).to have_content("Sadie Smith (teacher)")
  end

  def then_i_see_the_check_and_confirm_page
    expect(page).to have_content("Check and confirm")
  end

  def when_i_edit_the_vaccination_record
    click_on "Edit vaccination record"
  end

  def and_i_save_the_changes
    click_on "Save changes"
  end
end
