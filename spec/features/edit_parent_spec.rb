# frozen_string_literal: true

describe "Edit parent" do
  before { given_a_patient_with_a_parent_exists }

  scenario "User edits the name of a parent" do
    when_i_visit_the_patient_page
    and_i_click_on_edit_child_record
    and_i_click_on_change_parent
    then_i_see_the_edit_parent_page

    when_i_change_the_name_of_the_parent
    then_i_see_the_new_name_of_the_parent
  end

  scenario "User edits the relationship of a parent" do
    when_i_visit_the_patient_page
    and_i_click_on_edit_child_record
    and_i_click_on_change_parent
    then_i_see_the_edit_parent_page

    when_i_change_the_relationship_of_the_parent_to_mother
    then_i_see_the_new_relationship_of_the_parent_of_mother

    when_i_click_on_change_parent
    and_i_change_the_relationship_of_the_parent_to_other
    then_i_see_the_new_relationship_of_the_parent_of_other
  end

  scenario "User edits the contact details of a parent" do
    when_i_visit_the_patient_page
    and_i_click_on_edit_child_record
    and_i_click_on_change_parent
    then_i_see_the_edit_parent_page

    when_i_change_the_contact_details_of_the_parent
    then_i_see_the_new_contact_details_of_the_parent
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

  def when_i_click_on_change_parent
    click_on "Edit first parent or guardian"
  end

  alias_method :and_i_click_on_change_parent, :when_i_click_on_change_parent

  def then_i_see_the_edit_parent_page
    expect(page).to have_content("Details for first parent or guardian")
  end

  def when_i_change_the_name_of_the_parent
    fill_in "Name", with: "Selina Meyer"
    click_on "Continue"
  end

  def then_i_see_the_new_name_of_the_parent
    expect(page).to have_content("Selina Meyer")
  end

  def when_i_change_the_relationship_of_the_parent_to_mother
    choose "Mum"
    click_on "Continue"
  end

  def then_i_see_the_new_relationship_of_the_parent_of_mother
    expect(page).to have_content("mum")
  end

  def and_i_change_the_relationship_of_the_parent_to_other
    choose "Other", match: :first
    fill_in "Relationship to the child", with: "Someone"
    click_on "Continue"
  end

  def then_i_see_the_new_relationship_of_the_parent_of_other
    expect(page).to have_content("other – Someone")
  end

  def when_i_change_the_contact_details_of_the_parent
    fill_in "Email address", with: "selina@meyer.com"
    fill_in "Phone number", with: "07700 900 000"
    check "Get updates by text message"
    choose "They can only receive text messages"
    click_on "Continue"
  end

  def then_i_see_the_new_contact_details_of_the_parent
    expect(page).to have_content("selina@meyer.com")
    expect(page).to have_content("07700 900000")

    # Communication preferences aren't shown in the UI
    parent = Parent.last
    expect(parent.phone_receive_updates).to be(true)
    expect(parent.contact_method_type).to eq("text")
  end
end
