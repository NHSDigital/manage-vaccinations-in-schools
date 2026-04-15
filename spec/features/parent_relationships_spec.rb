# frozen_string_literal: true

describe "Parent relationships" do
  before { given_a_patient_exists }

  scenario "User removes a parent relationship from a patient" do
    and_the_patient_has_a_parent
    and_status_is_needs_consent_follow_up_requested
    when_i_visit_the_patient_page
    and_i_click_on_edit_child_record
    and_i_click_on_remove_parent
    then_i_see_the_delete_parent_relationship_page

    when_i_go_back_to_the_patient
    then_i_see_the_edit_child_record_page

    when_i_click_on_remove_parent
    and_i_delete_the_parent_relationship
    then_i_see_the_edit_child_record_page
    and_i_see_a_deletion_confirmation_message
    and_status_becomes_no_contact_details
  end

  scenario "User adds a parent relationship to a patient" do
    and_status_is_no_contact_details
    when_i_visit_the_patient_page
    and_i_click_on_edit_child_record
    and_i_click_on_add_parent_or_guardian
    then_i_see_the_add_parent_or_guardian_page

    and_i_fill_in_form_for_new_parent
    then_i_see_the_edit_child_record_page

    when_i_click_on_continue_to_confirm_changes
    then_status_is_no_longer_no_contact_details
  end

  def given_a_patient_exists
    @programmes = [Programme.sample]
    team = create(:team, programmes: @programmes)
    @nurse = create(:nurse, team:)

    session = create(:session, team:, programmes: @programmes)
    @patient = create(:patient, session:)
  end

  def and_the_patient_has_a_parent
    @parent = create(:parent)

    create(:parent_relationship, patient: @patient, parent: @parent)
  end

  def and_status_is_needs_consent_follow_up_requested
    create(
      :patient_programme_status,
      :needs_consent_follow_up_requested,
      patient: @patient,
      programme: @programmes.sole
    )
  end

  def and_status_is_no_contact_details
    create(
      :patient_programme_status,
      :needs_consent_no_contact_details,
      patient: @patient,
      programme: @programmes.sole
    )
  end

  def when_i_visit_the_patient_page
    sign_in @nurse
    visit patient_path(@patient)
  end

  def and_i_click_on_edit_child_record
    click_on "Edit child record"
  end

  def and_i_click_on_remove_parent
    click_on "Remove first parent or guardian"
  end

  def and_i_click_on_add_parent_or_guardian
    click_on "Add parent or guardian"
  end

  alias_method :when_i_click_on_remove_parent, :and_i_click_on_remove_parent

  def then_i_see_the_delete_parent_relationship_page
    expect(page).to have_content(
      "Are you sure you want to remove the relationship"
    )
  end

  def then_i_see_the_add_parent_or_guardian_page
    expect(page).to have_content("Add parent or guardian")
  end

  def when_i_go_back_to_the_patient
    click_on "No, return to child record"
  end

  def then_i_see_the_edit_child_record_page
    expect(page).to have_content("Edit child record")
  end

  def and_i_delete_the_parent_relationship
    click_on "Yes, remove this relationship"
  end

  def and_i_see_a_deletion_confirmation_message
    expect(page).to have_content("Parent relationship removed")
  end

  def and_status_becomes_no_contact_details
    expect(
      @patient
        .programme_statuses
        .where(programme_type: @programmes.sole)
        .first
        .consent_status
        .to_s
    ).to eq("no_contact_details")
  end

  def and_i_fill_in_form_for_new_parent
    fill_in "Name", with: "John Doe"

    within("fieldset", text: "Relationship to child") { choose "Dad" }

    fill_in "Email address", with: "john.doe@info.info"

    within("fieldset", text: "Does the parent have any specific needs?") do
      choose "They do not have specific needs"
    end

    click_on "Save"
  end

  def when_i_click_on_continue_to_confirm_changes
    click_on "Continue"
  end

  def then_status_is_no_longer_no_contact_details
    expect(
      @patient
        .programme_statuses
        .where(programme_type: @programmes.sole)
        .first
        .consent_status
        .to_s
    ).not_to eq("no_contact_details")
  end
end
