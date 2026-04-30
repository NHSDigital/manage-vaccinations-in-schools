# frozen_string_literal: true

describe "Adding a note to a child record" do
  scenario "nurse adds a note" do
    given_a_patient_exists
    and_i_am_signed_in

    when_i_visit_the_patient_page
    and_i_expand_the_add_a_note_form
    and_i_submit_the_form
    then_i_see_a_validation_error

    given_i_fill_in_a_note
    and_i_submit_the_form
    then_the_note_is_saved
    and_the_note_appears_in_the_activity_log
  end

  def given_a_patient_exists
    @team = create(:team, :with_one_nurse)
    @session = create(:session, team: @team)
    @patient = create(:patient, session: @session)
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def when_i_visit_the_patient_page
    visit patient_path(@patient)
  end

  def and_i_expand_the_add_a_note_form
    find("summary", text: "Add a note to this record").click
  end

  def given_i_fill_in_a_note
    fill_in "Note", with: "This is a test note."
  end

  def and_i_submit_the_form
    click_on "Save note"
  end

  def then_the_note_is_saved
    expect(page).to have_content("Note added")
  end

  def and_the_note_appears_in_the_activity_log
    expect(page).to have_content("Note added to child record")
    expect(page).to have_content("This is a test note.")
  end

  def then_i_see_a_validation_error
    expect(page).to have_css(".nhsuk-error-summary")
  end
end
