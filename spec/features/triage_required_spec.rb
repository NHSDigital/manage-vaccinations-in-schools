# frozen_string_literal: true

describe "Triage" do
  scenario "nurse can triage a patient for an HPV programme" do
    given_a_programme_with_a_running_session
    and_a_patient_who_needs_triage_exists
    and_a_patient_who_doesnt_need_triage_exists
    and_i_am_signed_in

    when_i_go_to_the_session_triage_tab
    then_i_see_the_patient_who_needs_triage
    and_i_dont_see_the_patient_who_doesnt_need_triage

    when_i_go_to_the_patient_that_needs_triage
    then_i_see_the_triage_options

    when_i_save_the_triage_without_choosing_an_option
    then_i_see_a_validation_error

    when_i_record_that_they_need_triage
    then_i_see_the_triage_options
    and_needs_triage_emails_are_sent_to_both_parents

    when_i_record_the_triage_decision_not_to_vaccinate
    and_vaccination_wont_happen_emails_are_sent_to_both_parents

    when_i_record_that_they_are_safe_to_vaccinate
    then_i_see_the_update_triage_link
    and_i_see_the_safe_triage_decision
    and_i_see_the_triage_status_tag
    and_vaccination_will_happen_emails_are_sent_to_both_parents
  end

  scenario "nurse triages a partially vaccinated MMR patient as safe to vaccinate" do
    given_an_mmr_programme_with_a_running_session
    and_a_partially_vaccinated_patient_who_needs_triage_exists
    and_i_am_signed_in

    when_i_go_to_the_session_triage_tab
    and_i_go_to_the_patient_that_needs_triage
    and_i_record_that_they_need_triage
    and_i_record_the_triage_decision_not_to_vaccinate
    and_i_record_that_they_are_safe_to_vaccinate

    then_the_mmr_second_dose_will_happen_email_is_sent
  end

  scenario "HCAs cannot triage" do
    given_a_flu_programme_with_a_running_session
    and_a_patient_who_needs_triage_exists
    and_i_am_signed_in_as_a_healthcare_assistant

    when_i_go_to_the_session_triage_tab
    then_i_see_the_patient_who_needs_triage

    when_i_go_to_the_patient_that_needs_triage
    then_i_dont_see_the_triage_options
  end

  scenario "nurse can triage patients for a flu programme with different consent types" do
    given_a_flu_programme_with_a_running_session
    and_patients_with_different_flu_consent_types_exist
    and_i_am_signed_in

    when_i_go_to_the_session_triage_tab
    then_i_see_both_patients_who_need_triage

    # First patient - injection only consent
    when_i_go_to_the_first_patient_that_needs_triage
    then_i_see_the_triage_options_for_injection_only_consent

    when_i_record_that_they_need_triage_for_flu
    then_i_see_the_triage_page
    and_needs_triage_emails_are_sent_to_both_parents

    when_i_record_that_they_are_safe_to_vaccinate_with_injection
    then_i_see_the_update_triage_link
    and_i_see_the_safe_triage_decision_with_method("injected")
    and_i_see_the_triage_status_tag(method: "injection")
    and_vaccination_will_happen_emails_are_sent_to_both_parents
    and_the_vaccine_method_is_recorded_as_injection

    # Second patient - nasal only consent
    when_i_go_to_the_session_triage_tab
    and_i_go_to_the_second_patient_that_needs_triage
    then_i_see_the_triage_options_for_nasal_only_consent

    when_i_record_that_they_need_triage_for_flu
    then_i_see_the_triage_page
    and_needs_triage_emails_are_sent_to_both_parents

    when_i_go_to_the_second_patient
    and_i_record_that_they_are_safe_to_vaccinate_with_nasal
    then_i_see_the_update_triage_link
    and_i_see_the_safe_triage_decision_with_method("nasal spray")
    and_i_see_the_triage_status_tag(method: "nasal spray")
    and_vaccination_will_happen_emails_are_sent_to_both_parents
    and_the_vaccine_method_is_recorded_as_nasal
  end

  scenario "prescriber can add add PSD instruction" do
    and_a_flu_programme_with_a_running_session_with_psd_enabled
    and_a_patient_with_nasal_consent_who_needs_triage_exists
    and_i_am_signed_in_as_a_prescriber

    when_i_go_to_the_session_triage_tab
    then_i_see_the_patient_who_needs_triage

    when_i_go_to_the_patient_that_needs_triage
    and_i_choose_that_they_are_safe_to_vaccinate_with_nasal
    and_i_choose_to_add_psd
    and_i_save_triage
    then_i_should_see_the_patient_tagged_psd_added

    when_i_click_on_the_update_triage_link
    and_i_choose_that_they_are_safe_to_vaccinate_with_nasal
    and_i_choose_not_to_add_psd
    and_i_save_triage
    then_i_should_see_the_patient_tagged_psd_not_added

    when_i_click_on_the_update_triage_link
    and_i_choose_that_they_are_safe_to_vaccinate_with_nasal
    and_i_choose_to_add_psd
    and_i_save_triage
    then_i_should_see_the_patient_tagged_psd_added

    when_i_click_on_the_update_triage_link
    and_i_record_the_triage_decision_not_to_vaccinate
    then_i_should_see_the_patient_tagged_psd_not_added
  end

  def given_a_programme_with_a_running_session
    programmes = [Programme.hpv]
    @team = create(:team, :with_one_nurse, programmes:)

    @batch =
      create(:batch, team: @team, vaccine: programmes.first.vaccines.first)

    @session = create(:session, team: @team, programmes:)
  end

  def given_a_flu_programme_with_a_running_session
    programmes = [Programme.flu]
    @team = create(:team, :with_one_nurse, programmes:)

    @batch =
      create(:batch, team: @team, vaccine: programmes.first.vaccines.first)

    @session = create(:session, team: @team, programmes:)
  end

  def and_a_flu_programme_with_a_running_session_with_psd_enabled
    programmes = [Programme.flu]
    @team = create(:team, :with_one_nurse, programmes:)

    @batch =
      create(:batch, team: @team, vaccine: programmes.first.vaccines.first)

    @session = create(:session, :psd_enabled, team: @team, programmes:)
  end

  def and_a_patient_who_needs_triage_exists
    @patient_triage_needed =
      create(:patient, :consent_given_triage_needed, session: @session)

    create(
      :consent,
      :given,
      :health_question_notes,
      :from_granddad,
      patient: @patient_triage_needed,
      programme: @session.programmes.first
    )

    @patient_triage_needed.reload # Make sure both consents are accessible
  end

  def and_a_patient_with_nasal_consent_who_needs_triage_exists
    @patient_triage_needed =
      create(
        :patient,
        :consent_given_nasal_only_triage_needed,
        session: @session
      )

    @patient_triage_needed.reload # Make sure both consents are accessible
  end

  def and_patients_with_different_flu_consent_types_exist
    @patient_injection_only =
      create(
        :patient,
        :consent_given_injection_only_triage_needed,
        session: @session
      )

    @patient_nasal_only =
      create(
        :patient,
        :consent_given_nasal_only_triage_needed,
        session: @session
      )

    @patient_injection_only.reload
    @patient_nasal_only.reload
  end

  def and_a_patient_who_doesnt_need_triage_exists
    @patient_triage_not_needed =
      create(:patient, :consent_given_triage_not_needed, session: @session)
  end

  def and_i_am_signed_in
    @user = @team.users.first
    sign_in @user
  end

  def and_i_am_signed_in_as_a_prescriber
    @user = @team.users.first
    sign_in @user, role: :prescriber
  end

  def and_i_am_signed_in_as_a_healthcare_assistant
    @user = @team.users.first
    sign_in @user, role: :healthcare_assistant
  end

  def when_i_go_to_the_session_triage_tab
    visit session_patients_path(@session)
    choose "Needs triage"
    click_on "Update results"
  end

  def then_i_see_the_patient_who_needs_triage
    expect(page).to have_content(@patient_triage_needed.full_name)
  end

  def then_i_see_both_patients_who_need_triage
    expect(page).to have_content(@patient_injection_only.full_name)
    expect(page).to have_content(@patient_nasal_only.full_name)
  end

  def and_i_dont_see_the_patient_who_doesnt_need_triage
    expect(page).not_to have_content(@patient_triage_not_needed.full_name)
  end

  def when_i_go_to_the_patient_that_needs_triage
    choose "Needs triage"
    click_on "Update results"
    click_link @patient_triage_needed.full_name
  end

  def then_i_see_the_triage_options
    expect(page).to have_content(
      "You need to decide if #{@patient_triage_needed.full_name} is safe to vaccinate."
    )
    expect(page).to have_selector(:heading, "Is it safe to vaccinate")
  end

  def then_i_dont_see_the_triage_options
    expect(page).to have_content(
      "A nurse needs to decide if #{@patient_triage_needed.full_name} is safe to vaccinate."
    )
    expect(page).not_to have_selector(:heading, "Is it safe to vaccinate")
  end

  def and_i_save_triage
    click_button "Save triage"
  end

  def when_i_record_that_they_need_triage
    choose "No, keep in triage"
    click_button "Save triage"
  end

  def when_i_record_that_they_need_triage_for_flu
    choose "No, keep in triage"
    click_button "Save triage"
  end

  def when_i_record_that_they_are_safe_to_vaccinate
    click_link "Update triage"
    choose "Yes, it’s safe to vaccinate"
    click_button "Save triage"
  end

  def when_i_record_that_they_are_safe_to_vaccinate_with_injection
    choose "Yes, it’s safe to vaccinate with injected vaccine"
    click_button "Save triage"
  end

  def and_i_record_that_they_are_safe_to_vaccinate_with_nasal
    and_i_choose_that_they_are_safe_to_vaccinate_with_nasal
    click_button "Save triage"
  end

  def and_i_choose_that_they_are_safe_to_vaccinate_with_nasal
    choose "Yes, it’s safe to vaccinate with nasal spray"
  end

  def and_i_choose_to_add_psd
    choose "Yes"
  end

  def and_i_choose_not_to_add_psd
    choose "No"
  end

  def when_i_record_the_triage_decision_not_to_vaccinate
    choose "No, do not vaccinate"
    click_button "Save triage"
  end

  alias_method :and_i_record_the_triage_decision_not_to_vaccinate,
               :when_i_record_the_triage_decision_not_to_vaccinate
  alias_method :and_i_go_to_the_patient_that_needs_triage,
               :when_i_go_to_the_patient_that_needs_triage
  alias_method :and_i_record_that_they_need_triage,
               :when_i_record_that_they_need_triage
  alias_method :and_i_record_that_they_are_safe_to_vaccinate,
               :when_i_record_that_they_are_safe_to_vaccinate

  def when_i_save_the_triage_without_choosing_an_option
    click_button "Save triage"
  end

  def then_i_see_a_validation_error
    expect(page).to have_selector :heading, "There is a problem"
  end

  def then_i_see_the_update_triage_link
    expect(page).to have_link "Update triage"
  end

  def and_i_see_the_safe_triage_decision
    expect(page).to have_content(
      "#{@user.full_name} decided that #{@patient_triage_needed.full_name} is safe to vaccinate."
    )
  end

  def and_i_see_the_triage_status_tag(method: nil)
    if method.present?
      expect(page).to have_content("Safe to vaccinate with #{method}")
    else
      expect(page).to have_content("Safe to vaccinate")
    end
  end

  def and_i_see_the_safe_triage_decision_with_method(method)
    patient =
      (
        if method == "injected"
          @patient_injection_only
        else
          @patient_nasal_only
        end
      )

    expect(page).to have_content(
      "#{@user.full_name} decided that #{patient.full_name} is safe to vaccinate using the #{method} vaccine only."
    )
  end

  def then_i_see_the_triage_page
    expect(page).to have_selector :heading, "Is it safe to vaccinate"
  end

  def and_needs_triage_emails_are_sent_to_both_parents
    current_patient =
      @patient_triage_needed || @patient_injection_only || @patient_nasal_only
    current_patient.parents.each do |parent|
      expect_email_to parent.email, :consent_confirmation_triage, :any
    end
  end

  def and_vaccination_wont_happen_emails_are_sent_to_both_parents
    current_patient =
      @patient_triage_needed || @patient_injection_only || @patient_nasal_only
    current_patient.parents.each do |parent|
      expect_email_to parent.email, :triage_vaccination_wont_happen, :any
    end
  end

  def and_vaccination_will_happen_emails_are_sent_to_both_parents
    current_patient =
      @patient_triage_needed || @patient_injection_only || @patient_nasal_only
    current_patient.parents.each do |parent|
      expect(email_deliveries).to include(
        matching_notify_email(
          to: parent.email,
          template: :triage_vaccination_will_happen
        ).with_content_including(
          "confirmed it\u2019s safe",
          "We\u2019ll let you know once"
        )
      )
    end
  end

  def and_the_vaccine_method_is_recorded_as_injection
    current_patient =
      @patient_triage_needed || @patient_injection_only || @patient_nasal_only
    triage = current_patient.triages.last
    expect(triage.vaccine_method).to eq("injection")
  end

  def when_i_go_to_the_first_patient_that_needs_triage
    choose "Needs triage"
    click_on "Update results"
    click_link @patient_injection_only.full_name
  end

  def then_i_see_the_triage_options_for_injection_only_consent
    expect(page).to have_selector :heading,
                  "Is it safe to vaccinate #{@patient_injection_only.given_name}?"
    expect(page).to have_content(
      "The parent has consented to the injected vaccine only"
    )
    expect(page).to have_field(
      "Yes, it’s safe to vaccinate with injected vaccine",
      type: "radio"
    )
  end

  def and_i_go_to_the_second_patient_that_needs_triage
    choose "Needs triage"
    click_on "Update results"
    click_link @patient_nasal_only.full_name
  end

  def then_i_see_the_triage_options_for_nasal_only_consent
    expect(page).to have_selector :heading,
                  "Is it safe to vaccinate #{@patient_nasal_only.given_name}?"
    expect(page).to have_content(
      "The parent has consented to the nasal spray only"
    )
    expect(page).to have_field(
      "Yes, it’s safe to vaccinate with nasal spray",
      type: "radio"
    )
  end

  def when_i_go_to_the_second_patient
    within(".nhsuk-breadcrumb") { click_on "Children" }
    click_link @patient_nasal_only.full_name, match: :first
  end

  def and_the_vaccine_method_is_recorded_as_nasal
    triage = @patient_nasal_only.triages.last
    expect(triage.vaccine_method).to eq("nasal")
  end

  def then_i_should_see_the_patient_tagged_psd_added
    within(".app-action-list") { expect(page).to have_content("PSD added") }
  end

  def then_i_should_see_the_patient_tagged_psd_not_added
    within(".app-action-list") { expect(page).to have_content("PSD not added") }
  end

  def then_i_should_see_the_patient_with_status_psd_added
    expect(page).to have_content("PSD added")
  end

  def when_i_click_on_the_update_triage_link
    click_link "Update triage outcome"
  end

  def given_an_mmr_programme_with_a_running_session
    programmes = [Programme.mmr]
    @team = create(:team, :with_one_nurse, programmes:)
    @batch =
      create(:batch, team: @team, vaccine: programmes.first.vaccines.first)
    @session = create(:session, team: @team, programmes:)
  end

  def and_a_partially_vaccinated_patient_who_needs_triage_exists
    @patient_triage_needed =
      create(:patient, :partially_vaccinated_triage_needed, session: @session)
  end

  def then_the_mmr_second_dose_will_happen_email_is_sent
    @patient_triage_needed.parents.each do |parent|
      expect(email_deliveries).to include(
        matching_notify_email(
          to: parent.email,
          template: :triage_vaccination_will_happen_mmr_second_dose
        ).with_content_including("We recently gave", "2nd dose")
      )
    end
  end
end
