# frozen_string_literal: true

describe "Verbal consent" do
  around { |example| travel_to(Date.new(2025, 7, 31)) { example.run } }

  before { given_i_am_signed_in }

  scenario "Given by a new mother parent contact" do
    when_i_start_recording_consent_from_a_new_parental_contact
    and_i_enter_a_mum_relationship
    and_i_record_that_verbal_consent_was_given
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_i_can_see_the_parents_details_on_the_consent_response(
      relationship: "Mum"
    )
  end

  scenario "Given by a new other parent contact" do
    when_i_start_recording_consent_from_a_new_parental_contact
    and_i_enter_an_other_relationship
    and_i_record_that_verbal_consent_was_given
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_i_can_see_the_parents_details_on_the_consent_response(
      relationship: "Other – Carer"
    )
  end

  def given_i_am_signed_in
    programmes = [Programme.hpv]
    team = create(:team, :with_one_nurse, programmes:)
    @session = create(:session, team:, programmes:)
    @patient = create(:patient, session: @session)

    PatientStatusUpdater.call

    sign_in team.users.first
  end

  def when_i_start_recording_consent_from_a_new_parental_contact
    visit session_patients_path(@session)
    click_link @patient.full_name
    click_on "Record a new consent response"

    # Who are you trying to get consent from?
    choose "Add a new parental contact"
    click_button "Continue"
  end

  def and_i_enter_a_mum_relationship
    fill_in "Full name", with: "Jane Smith"
    choose "Mum"
    fill_in "Email address", with: "jsmith@example.com"
    fill_in "Phone number", with: "07987654321"
    check "Get updates by text"
    click_button "Continue"
  end

  def and_i_enter_an_other_relationship
    fill_in "Full name", with: "Jane Smith"
    choose "Other"

    click_button "Continue"
    expect(page).to have_content("Enter a relationship")
    expect(page).to have_content(
      "Choose whether there is parental responsibility"
    )

    fill_in "Relationship to the child", with: "Carer"
    choose "Yes"

    fill_in "Email address", with: "jsmith@example.com"
    fill_in "Phone number", with: "07987654321"
    check "Get updates by text"
    click_button "Continue"
  end

  def and_i_record_that_verbal_consent_was_given
    # How was the response given?
    choose "By phone"
    click_button "Continue"

    # Do they agree?
    choose "Yes, they agree"
    click_button "Continue"

    # Health questions
    find_all(".nhsuk-fieldset")[0].choose "No"
    find_all(".nhsuk-fieldset")[1].choose "No"
    find_all(".nhsuk-fieldset")[2].choose "No"
    find_all(".nhsuk-fieldset")[3].choose "No"
    click_button "Continue"

    # Confirm
    expect(page).to have_content("Check and confirm answers")
    expect(page).to have_content(["Method", "By phone"].join)
    click_button "Confirm"

    # Back on the consent responses page
    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def and_i_can_see_the_parents_details_on_the_consent_response(relationship:)
    click_link @patient.full_name, match: :first
    click_link "Jane Smith"

    expect(page).to have_content("Consent response from Jane Smith")

    expect(page).to have_content(["Name", "Jane Smith"].join)
    expect(page).to have_content(["Relationship", relationship].join)
    expect(page).to have_content(
      ["Email address", "jsmith@example.com"].join("\n")
    )
    expect(page).to have_content(["Phone number", "07987 654321"].join("\n"))
  end

  def then_an_email_is_sent_to_the_parent_confirming_their_consent
    expect_email_to("jsmith@example.com", :consent_confirmation_given)
  end

  def and_i_a_text_is_sent_to_the_parent_confirming_their_consent
    expect_sms_to("07987 654321", :consent_confirmation_given)
  end
end
