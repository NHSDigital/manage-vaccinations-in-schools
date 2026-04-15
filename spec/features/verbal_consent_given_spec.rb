# frozen_string_literal: true

describe "Verbal consent" do
  before { Flipper.enable(:one_patient_per_parent) }

  scenario "Given HPV" do
    given_an_hpv_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_consent_was_given
    then_i_see_the_check_and_confirm_page

    when_i_confirm_the_consent_response
    then_the_parent_details_are_saved_to_the_consent
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
    and_i_can_see_the_consent_response_details(number_of_health_questions: 4)
    and_i_can_see_the_log_entries_for_the_email_and_sms
  end

  scenario "Given flu injection" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_injection_consent_was_given
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_injection_consent_given

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
  end

  scenario "Given flu injection with a PSD already" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in
    and_the_patient_has_a_psd

    when_i_record_that_verbal_injection_consent_was_given
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_injection_consent_given

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
    and_the_psd_is_invalidated
  end

  scenario "Given flu nasal spray" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_nasal_consent_was_given
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_nasal_consent_given

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
  end

  scenario "Given flu nasal spray and injection" do
    given_a_flu_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_nasal_and_injection_consent_was_given
    then_i_see_the_check_and_confirm_page
    and_i_see_the_flu_nasal_and_injection_consent_given

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
  end

  scenario "Given MMR" do
    given_an_mmr_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_consent_was_given_with_gelatine
    then_i_see_the_check_and_confirm_page

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
    and_i_can_see_the_consent_response_details(number_of_health_questions: 3)
  end

  scenario "Given MMR without gelatine" do
    given_an_mmr_programme_is_underway
    and_i_am_signed_in

    when_i_record_that_verbal_consent_was_given_without_gelatine
    then_i_see_the_check_and_confirm_page

    when_i_confirm_the_consent_response
    then_an_email_is_sent_to_the_parent_confirming_their_consent
    and_a_text_is_sent_to_the_parent_confirming_their_consent
    and_i_can_see_the_consent_response_details(number_of_health_questions: 3)
  end

  def given_an_hpv_programme_is_underway
    create_programme(Programme.hpv)
  end

  def given_a_flu_programme_is_underway
    create_programme(Programme.flu)
  end

  def given_an_mmr_programme_is_underway
    create_programme(Programme.mmr)
  end

  def create_programme(programme)
    @programme = programme
    programmes = [@programme]
    @team = create(:team, :with_one_nurse, programmes:)
    @session = create(:session, team: @team, programmes:)

    @patient =
      create(
        :patient,
        given_name: "Alex",
        session: @session,
        date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.year
      )
    @parent = create(:parent, patient: @patient)

    PatientStatusUpdater.call
  end

  def and_i_am_signed_in
    sign_in @team.users.first
  end

  def and_the_patient_has_a_psd
    @patient_specific_direction =
      create(
        :patient_specific_direction,
        patient: @patient,
        programme: @programme
      )
  end

  def when_i_record_that_verbal_consent_was_given
    record_that_verbal_consent_was_given(
      consent_option: "Yes, they agree",
      number_of_health_questions: 4
    )
  end

  def when_i_record_that_verbal_injection_consent_was_given
    record_that_verbal_consent_was_given(
      consent_option: "Yes, for the injected vaccine only",
      number_of_health_questions: 4
    )
  end

  def when_i_record_that_verbal_nasal_consent_was_given
    record_that_verbal_consent_was_given(
      consent_option: "Yes, for the nasal spray",
      number_of_health_questions: 9
    )
  end

  def when_i_record_that_verbal_nasal_and_injection_consent_was_given
    record_that_verbal_consent_was_given(
      consent_option: "Yes, for the nasal spray",
      number_of_health_questions: 10,
      injective_alternative: true
    )
  end

  def when_i_record_that_verbal_consent_was_given_with_gelatine
    record_that_verbal_consent_was_given(
      consent_option: "Yes, they agree",
      number_of_health_questions: 3,
      without_gelatine: false
    )
  end

  def when_i_record_that_verbal_consent_was_given_without_gelatine
    record_that_verbal_consent_was_given(
      consent_option: "Yes, they agree",
      number_of_health_questions: 3,
      without_gelatine: true
    )
  end

  def record_that_verbal_consent_was_given(
    consent_option:,
    number_of_health_questions:,
    injective_alternative: nil,
    without_gelatine: nil
  )
    visit session_patients_path(@session)
    click_link @patient.full_name
    click_button "Record a new consent response"

    # Who are you trying to get consent from?
    click_button "Continue"
    expect(page).to have_content(
      "Choose who you are trying to get consent from"
    )

    parent_label = @patient.parents.find_by(patient: @patient).label_with_parent

    choose parent_label
    click_button "Continue"

    # Details for parent or guardian
    expect(page).to have_content("Details for #{parent_label}")
    # don't change any details
    click_button "Continue"

    # How was the response given?
    choose "By phone"
    click_button "Continue"

    # Do they agree?
    choose consent_option
    if consent_option.include?("nasal")
      choose injective_alternative ? "Yes" : "No"
    end
    unless without_gelatine.nil?
      if without_gelatine
        choose "Yes, they want their child to have a vaccine that does not contain gelatine"
      else
        choose "Their child can have either type of vaccine"
      end
    end
    click_button "Continue"

    number_of_health_questions.times do |index|
      find_all(".nhsuk-fieldset")[index].choose "No"
    end

    click_button "Continue"
  end

  def then_i_see_the_check_and_confirm_page
    expect(page).to have_content("Check and confirm answers")
    expect(page).to have_content(["Method", "By phone"].join)
    expect(page).not_to have_content(
      "Confirmation of vaccination sent to parent"
    )
  end

  def and_i_see_the_flu_injection_consent_given
    expect(page).to have_content("ResponseConsent given")
    expect(page).to have_content("Chosen vaccineInjected vaccine only")
  end

  def and_i_see_the_flu_nasal_consent_given
    expect(page).to have_content("ResponseConsent given")
    expect(page).to have_content("Chosen vaccineNasal spray only")
  end

  def and_i_see_the_flu_nasal_and_injection_consent_given
    expect(page).to have_content("ResponseConsent given")
    expect(page).to have_content(
      "Chosen vaccineNasal spray or injected vaccine"
    )
  end

  def when_i_confirm_the_consent_response
    click_button "Confirm"
    expect(page).to have_content("Consent recorded for #{@patient.full_name}")
  end

  def then_the_parent_details_are_saved_to_the_consent
    consent = @patient.consents.last
    parent = @patient.parents.first

    expect(consent).to have_attributes(
      parent_full_name: @parent.full_name,
      parent_email: @parent.email,
      parent_phone: @parent.phone,
      parent_phone_receive_updates: @parent.phone_receive_updates,
      parent_relationship_type: parent.type
    )

    expect(consent.parent_relationship_other_name.to_s).to eq(
      parent.other_name.to_s
    )
  end

  def and_i_can_see_the_consent_response_details(number_of_health_questions:)
    click_link @patient.full_name, match: :first
    click_link @parent.full_name

    expect(page).to have_content("Consent response from #{@parent.full_name}")
    expect(page).to have_content(["Date", Date.current.to_fs(:long)].join)
    expect(page).to have_content(["Response", "Consent given"].join)
    expect(page).to have_content(["Method", "By phone"].join)

    expect(page).to have_content(["Full name", @patient.full_name].join)
    expect(page).to have_content(
      ["Date of birth", @patient.date_of_birth.to_fs(:long)].join
    )
    expect(page).to have_content(["School", @patient.school.name].join)

    expect(page).to have_content(["Name", @parent.full_name].join)
    expect(page).to have_content(
      ["Relationship", @patient.parents.first.relationship_type_label].join
    )
    expect(page).to have_content(["Email address", @parent.email].join("\n"))
    expect(page).to have_content(["Phone number", @parent.phone].join("\n"))

    expect(page).to have_content("Answers to health questions")
    expect(page).to have_content(
      "#{@patient.parents.first.relationship_type_label} responded: No",
      count: number_of_health_questions
    )
  end

  def then_an_email_is_sent_to_the_parent_confirming_their_consent
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template: :consent_confirmation_given
      ).with_content_including("You’ve given consent", "withdraw your consent")
    )
  end

  def and_a_text_is_sent_to_the_parent_confirming_their_consent
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :consent_confirmation_given
      ).with_content_including(
        "You've given consent for Alex",
        "Please let them know what to expect"
      )
    )
  end

  def and_the_psd_is_invalidated
    expect(@patient_specific_direction.reload).to be_invalidated
  end

  def and_i_can_see_the_log_entries_for_the_email_and_sms
    click_on "Back"
    click_on "Session activity and notes"
    expect(page).to have_content("Consent confirmation given", count: 2)
    expect(page).to have_content(@parent.email)
    expect(page).to have_content(@parent.phone)
  end
end
