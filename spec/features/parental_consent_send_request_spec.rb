# frozen_string_literal: true

describe "Parental consent" do
  around { |example| travel_to(Date.new(2024, 1, 1)) { example.run } }

  scenario "Send school request where patient is eligible for HPV" do
    given_a_programme_exists(:hpv)
    and_a_school_session_with_hpv_eligible_patient_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_an_hpv_school_request_email_is_sent_to_the_parent
    and_an_hpv_school_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("HPV", setting: :school)
  end

  scenario "Send school request where patient is eligible for flu" do
    given_a_programme_exists(:flu)
    and_a_school_session_with_flu_eligible_patient_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_a_flu_school_request_email_is_sent_to_the_parent
    and_a_flu_school_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("Flu", setting: :school)
  end

  scenario "Send school request where patient is eligible for doubles" do
    given_programmes_exists(:td_ipv, :menacwy)
    and_a_school_session_with_doubles_eligible_patient_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_a_doubles_school_request_email_is_sent_to_the_parent
    and_a_doubles_school_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email(
      "Doubles",
      setting: :school,
      programme_display_name: "MenACWY Td/IPV"
    )
  end

  scenario "Send clinic request where patient is eligible for HPV" do
    given_a_programme_exists(:hpv)
    and_a_patient_without_consent_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_a_clinic_request_email_is_sent_to_the_parent
    and_a_clinic_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("HPV")
    and_an_activity_log_entry_is_visible_for_the_text("HPV")
  end

  scenario "Send clinic request for doubles" do
    given_programmes_exists(:td_ipv, :menacwy)
    and_a_patient_without_consent_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_i_see_a_consent_request_has_been_sent
    and_a_clinic_request_email_is_sent_to_the_parent
    and_a_clinic_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("MenACWY Td/IPV")
    and_an_activity_log_entry_is_visible_for_the_text("MenACWY Td/IPV")
  end

  scenario "Send clinic request where patient is eligible for MMRV" do
    given_a_programme_exists(:mmr)
    and_a_patient_without_consent_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_a_clinic_request_email_is_sent_to_the_parent
    and_a_clinic_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("MMRV")
    and_an_activity_log_entry_is_visible_for_the_text("MMRV")
  end

  scenario "Send school request where patient is eligible for MMRV" do
    given_a_programme_exists(:mmr)
    and_a_school_session_with_mmrv_eligible_patient_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_an_mmrv_school_request_email_is_sent_to_the_parent
    and_an_mmrv_school_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email(
      "MMRV",
      setting: :school
    )
  end

  scenario "Send school outbreak request where patient is eligible for MMRV" do
    given_a_programme_exists(:mmr)
    and_a_school_session_with_mmrv_eligible_patient_exists(outbreak: true)
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_an_mmrv_school_request_email_is_sent_to_the_parent(outbreak: true)
    and_an_mmrv_school_request_sms_is_sent_to_the_parent(outbreak: true)

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email(
      "MMRV",
      setting: :school,
      outbreak: true
    )
  end

  scenario "Send school request where patient is eligible for MMR only" do
    given_a_programme_exists(:mmr)
    and_a_school_session_with_mmr_only_patient_exists
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_an_mmr_school_request_email_is_sent_to_the_parent
    and_an_mmr_school_request_sms_is_sent_to_the_parent

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email("MMR", setting: :school)
  end

  scenario "Send school outbreak request where patient is eligible for MMR only" do
    given_a_programme_exists(:mmr)
    and_a_school_session_with_mmr_only_patient_exists(outbreak: true)
    and_i_am_signed_in

    when_i_go_to_a_patient_without_consent
    then_i_see_no_requests_sent

    when_i_click_send_consent_request
    then_i_see_the_confirmation_banner
    and_an_mmr_school_request_email_is_sent_to_the_parent(outbreak: true)
    and_an_mmr_school_request_sms_is_sent_to_the_parent(outbreak: true)

    when_i_click_on_session_activity_and_notes
    then_an_activity_log_entry_is_visible_for_the_email(
      "MMR",
      setting: :school,
      outbreak: true
    )
  end

  def given_a_programme_exists(*programme_types)
    @programmes = programme_types.collect { Programme.public_send(_1) }
  end
  alias_method :given_programmes_exists, :given_a_programme_exists

  def and_a_patient_without_consent_exists
    @team = create(:team, :with_one_nurse, programmes: @programmes)
    @user = @team.users.first

    location = @team.generic_clinic

    @session =
      create(
        :session,
        team: @team,
        programmes: @programmes,
        location:,
        date: Date.current + 2.days
      )

    @parent = create(:parent)
    @patient =
      create(
        :patient,
        session: @session,
        parents: [@parent],
        date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month
      )

    PatientStatusUpdater.call
  end

  def and_a_school_session_with_hpv_eligible_patient_exists(outbreak: false)
    create_school_session_with_patient(date_of_birth: 12.years.ago, outbreak:)
  end

  def and_a_school_session_with_flu_eligible_patient_exists(outbreak: false)
    create_school_session_with_patient(date_of_birth: 12.years.ago, outbreak:)
  end

  def and_a_school_session_with_doubles_eligible_patient_exists(outbreak: false)
    create_school_session_with_patient(date_of_birth: 12.years.ago, outbreak:)
  end

  def and_a_school_session_with_mmrv_eligible_patient_exists(outbreak: false)
    create_school_session_with_patient(
      date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE + 1.month,
      outbreak:
    )
  end

  def and_a_school_session_with_mmr_only_patient_exists(outbreak: false)
    create_school_session_with_patient(
      date_of_birth: Programme::MIN_MMRV_ELIGIBILITY_DATE - 1.month,
      outbreak:
    )
  end

  def and_i_am_signed_in
    sign_in @user
  end

  def when_i_go_to_a_patient_without_consent
    visit session_patients_path(@session)
    click_link @patient.full_name
  end

  def then_i_see_no_requests_sent
    expect(page).to have_content("No requests have been sent.")
  end

  def when_i_click_send_consent_request
    click_on "Send consent request"
  end

  def then_i_see_the_confirmation_banner
    expect(page).to have_content("Consent request sent.")
  end

  def and_i_see_a_consent_request_has_been_sent
    expect(page).to have_content(
      "No-one responded to our requests for consent."
    )
    expect(page).to have_content("A request was sent on")
  end

  def and_a_clinic_request_email_is_sent_to_the_parent
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template: :consent_clinic_request
      ).with_content_including(
        "You recently booked",
        "Please give consent",
        "If you need to contact us"
      )
    )
  end

  def and_a_clinic_request_sms_is_sent_to_the_parent
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :consent_clinic_request
      ).with_content_including(
        "You recently booked a clinic appointment",
        "Please give consent for them to get the"
      )
    )
  end

  def and_an_hpv_school_request_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_school_request_hpv)
  end

  def and_an_hpv_school_request_sms_is_sent_to_the_parent
    expect_sms_to(@parent.phone, :consent_school_request)
  end

  def and_a_flu_school_request_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_school_request_flu)
  end

  def and_a_flu_school_request_sms_is_sent_to_the_parent
    expect_sms_to(@parent.phone, :consent_school_request)
  end

  def and_a_doubles_school_request_email_is_sent_to_the_parent
    expect_email_to(@parent.email, :consent_school_request_doubles)
  end

  def and_a_doubles_school_request_sms_is_sent_to_the_parent
    expect_sms_to(@parent.phone, :consent_school_request)
  end

  def and_an_mmrv_school_request_email_is_sent_to_the_parent(outbreak: false)
    template =
      (
        if outbreak
          :consent_school_request_mmrv_outbreak
        else
          :consent_school_request_mmrv
        end
      )
    content =
      if outbreak
        [
          "The number of measles cases in your area is high right now.",
          "## We’re offering catch-up vaccinations",
          "Respond to the consent request now",
          "## Contact us"
        ]
      else
        [
          "## About the MMRV vaccine",
          "Respond to the consent request now",
          "## Contact us"
        ]
      end
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template:
      ).with_content_including(*content)
    )
  end

  def and_an_mmrv_school_request_sms_is_sent_to_the_parent(outbreak: false)
    and_an_mmr_school_request_sms_is_sent_to_the_parent(
      mmrv_eligible: true,
      outbreak:
    )
  end

  def and_an_mmr_school_request_email_is_sent_to_the_parent(outbreak: false)
    template =
      (
        if outbreak
          :consent_school_request_mmr_outbreak
        else
          :consent_school_request_mmr
        end
      )
    content =
      if outbreak
        [
          "The number of measles cases in your area is high right now.",
          "## We’re offering catch-up vaccinations",
          "Respond to the consent request now",
          "## Contact us"
        ]
      else
        ["Respond to the consent request now", "## Contact us"]
      end
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template:
      ).with_content_including(*content)
    )
  end

  def and_an_mmr_school_request_sms_is_sent_to_the_parent(
    mmrv_eligible: false,
    outbreak: false
  )
    dose_text = mmrv_eligible ? "MMR or MMRV vaccine?" : "MMR vaccine?"

    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :consent_school_request_mmr
      ).with_content_including("Has your child had 2 doses of the #{dose_text}")
    )

    outbreak_matcher =
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :consent_school_request_mmr
      ).with_content_including(
        "Cases of measles in your area are high right now."
      )

    if outbreak
      expect(sms_deliveries).to include(outbreak_matcher)
    else
      expect(sms_deliveries).not_to include(outbreak_matcher)
    end
  end

  def when_i_click_on_session_activity_and_notes
    click_on "Session activity and notes"
  end

  def then_an_activity_log_entry_is_visible_for_the_email(
    programme_name,
    setting: :clinic,
    outbreak: false,
    programme_display_name: nil
  )
    outbreak_text = outbreak ? " outbreak" : ""
    location_text = setting.to_s
    programme_text = setting == :clinic ? "" : " #{programme_name.downcase}"
    title =
      "Consent #{location_text} request#{programme_text}#{outbreak_text} sent"
    display_name = programme_display_name || programme_name

    expect(page).to have_content(
      "#{title}\n" \
        "#{display_name} USER, Test · 1 January 2024 at 12:00am\n#{@parent.email}"
    )
  end

  def and_an_activity_log_entry_is_visible_for_the_text(programme_name)
    click_on "Session activity and notes"
    expect(page).to have_content(
      "Consent clinic request sent\n" \
        "#{programme_name} USER, Test · 1 January 2024 at 12:00am\n#{@parent.phone}"
    )
  end

  private

  def create_school_session_with_patient(date_of_birth:, outbreak: false)
    @team = create(:team, :with_one_nurse, programmes: @programmes)
    @user = @team.users.first

    location = create(:gias_school, team: @team, programmes: @programmes)

    @session =
      create(
        :session,
        team: @team,
        programmes: @programmes,
        location:,
        date: Date.current + 2.days,
        outbreak:
      )

    @parent = create(:parent)
    @patient =
      create(:patient, session: @session, parents: [@parent], date_of_birth:)

    PatientStatusUpdater.call
  end
end
