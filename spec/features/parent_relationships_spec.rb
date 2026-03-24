# frozen_string_literal: true

describe "Parent relationships" do
  before { given_a_patient_with_a_parent_exists }

  scenario "User removes a parent relationship from a patient" do
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
  end

  def given_a_patient_with_a_parent_exists
    programmes = [Programme.sample]
    team = create(:team, programmes:)
    @nurse = create(:nurse, team:)

    session = create(:session, team:, programmes:)
    @patient = create(:patient, session:)

    @parent = create(:parent)

    create(:parent_relationship, patient: @patient, parent: @parent)
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

  alias_method :when_i_click_on_remove_parent, :and_i_click_on_remove_parent

  def then_i_see_the_delete_parent_relationship_page
    expect(page).to have_content(
      "Are you sure you want to remove the relationship"
    )
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
end
