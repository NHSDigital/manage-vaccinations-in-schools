# frozen_string_literal: true

describe "Scheduled consent requests and reminders" do
  around { |example| travel_to(Time.zone.local(2024, 2, 18)) { example.run } }

  let(:request_templates) do
    %i[
      consent_school_request_hpv
      consent_school_request_flu
      consent_school_request_mmr
      consent_school_request_doubles
    ]
  end

  let(:reminder_templates) do
    %i[
      consent_school_reminder_hpv
      consent_school_reminder_flu
      consent_school_reminder_mmr
      consent_school_reminder_doubles
    ]
  end

  let(:parent_emails) do
    %w[
      parent1.child1@example.com
      parent2.child1@example.com
      parent1.child2@example.com
      parent2.child2@example.com
    ]
  end

  let(:parent_phones) do
    ["07700 900000", "07700 900001", "07700 900002", "07700 900003"]
  end

  let(:mmrv_parent_emails) do
    %w[parent1.child3@example.com parent2.child3@example.com]
  end

  let(:mmrv_parent_phones) { ["07700 900004", "07700 900005"] }

  scenario "Consent requests and reminders are sent automatically" do
    given_my_team_is_running_all_vaccination_programmes
    and_one_unscheduled_session_exists_with_two_children_and_two_parents_each
    and_an_mmrv_eligible_child_with_two_parents_exists
    and_i_am_signed_in

    when_i_go_to_my_team_page
    and_i_click_on_sessions
    then_i_see_consent_requests_are_sent_3_weeks_before

    when_i_schedule_a_session_4_weeks_away
    and_6_days_pass
    then_no_consent_requests_have_been_sent

    when_1_more_day_passes
    then_all_four_parents_received_all_programme_consent_requests

    when_14_more_days_pass
    then_all_four_parents_received_all_programme_reminders

    when_7_more_days_pass
    then_all_four_parents_received_all_programme_reminders
  end

  def given_my_team_is_running_all_vaccination_programmes
    programmes = [
      Programme.hpv,
      Programme.flu,
      Programme.mmr,
      Programme.menacwy,
      Programme.td_ipv
    ]
    @team = create(:team, :with_one_nurse, programmes:)
    @location = create(:gias_school, team: @team)
    @session =
      create(
        :session,
        :unscheduled,
        location: @location,
        team: @team,
        programmes:
      )
    @user = @team.users.first
  end

  def and_one_unscheduled_session_exists_with_two_children_and_two_parents_each
    # Year 9 is in the intersection of all programme year groups (HPV 8-11,
    # flu 0-11, MMR 0-11, MenACWY 9-11, Td/IPV 9-11).
    2.times do |i|
      parents = [
        create(
          :parent,
          email: "parent1.child#{i + 1}@example.com",
          phone: "0770090000#{2 * i}",
          phone_receive_updates: true
        ),
        create(
          :parent,
          email: "parent2.child#{i + 1}@example.com",
          phone: "0770090000#{2 * i + 1}",
          phone_receive_updates: true
        )
      ]
      create(
        :patient,
        year_group: 9,
        session: @session,
        given_name: "Child#{i + 1}",
        family_name: "Test",
        parents:
      )
    end
  end

  def and_an_mmrv_eligible_child_with_two_parents_exists
    parents = [
      create(
        :parent,
        email: "parent1.child3@example.com",
        phone: "07700900004",
        phone_receive_updates: true
      ),
      create(
        :parent,
        email: "parent2.child3@example.com",
        phone: "07700900005",
        phone_receive_updates: true
      )
    ]
    # Child3 is born after the MMRV eligibility cutoff (2020-01-01) so they
    # receive MMRV consent request and reminder emails.
    create(
      :patient,
      date_of_birth: Date.new(2020, 6, 1),
      session: @session,
      given_name: "Child3",
      family_name: "Test",
      parents:
    )
  end

  def and_i_am_signed_in
    sign_in @user
  end

  def when_i_go_to_my_team_page
    visit "/"
    click_link "Your team", match: :first
  end

  def and_i_click_on_sessions
    find(".app-sub-navigation__link", text: "Sessions").click
  end

  def then_i_see_consent_requests_are_sent_3_weeks_before
    expect(page).to have_content(
      ["Consent requests", "Send 3 weeks before first session"].join
    )
  end

  def when_i_schedule_a_session_4_weeks_away
    click_link "Sessions", match: :first
    choose "Unscheduled"
    click_button "Update results"
    click_link @location.name
    click_link "Edit session"
    click_link "Add session dates"

    session_date = 4.weeks.from_now

    fill_in "Day", with: session_date.day
    fill_in "Month", with: session_date.month
    fill_in "Year", with: session_date.year

    click_button "Continue"
    click_on "Keep session dates" if has_button?("Keep session dates")
    click_button "Save changes"
  end

  def and_6_days_pass
    travel 6.days
  end

  def when_1_more_day_passes
    travel 1.day
  end

  def then_no_consent_requests_have_been_sent
    EnqueueSchoolConsentRequestsJob.new.perform
    Sidekiq::Job.drain_all

    expect(email_deliveries).to be_empty
    expect(sms_deliveries).to be_empty
  end

  def when_14_more_days_pass
    travel 14.days
    # Add a follow-up session date 2 weeks from now so the subsequent reminder
    # will be due 7 days later (when_7_more_days_pass).
    # days_before_consent_reminders is nil for sessions created unscheduled; the
    # send_consent_reminders scope requires it to be set.
    @session.reload.update!(
      dates: @session.dates + [Date.current + 2.weeks],
      days_before_consent_reminders:
        @session.days_before_consent_reminders ||
          @session.team.days_before_consent_reminders
    )
  end

  def when_7_more_days_pass
    travel 7.days
  end

  def then_all_four_parents_received_all_programme_consent_requests
    EnqueueSchoolConsentRequestsJob.new.perform
    Sidekiq::Job.drain_all

    parent_emails.each do |email|
      request_templates.each do |template|
        expect(email_deliveries).to include(
          matching_notify_email(to: email, template:)
        )
      end
    end

    expect(email_deliveries).to include(
      matching_notify_email(
        to: "parent1.child1@example.com",
        template: :consent_school_request_hpv
      ).with_content_including(
        "We’re coming to",
        "Respond to the consent request now",
        "## Contact us"
      )
    )

    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: "07700 900000",
        template: :consent_school_request
      ).with_content_including(
        "Give or refuse consent",
        "Responding will take less than 5 minutes"
      )
    )

    parent_phones.each do |phone|
      expect_sms_to(phone, :consent_school_request, :any)
    end

    mmrv_parent_emails.each do |email|
      expect(email_deliveries).to include(
        matching_notify_email(to: email, template: :consent_school_request_mmrv)
      )
    end

    mmrv_parent_phones.each do |phone|
      expect_sms_to(phone, :consent_school_request, :any)
    end
  end

  def then_all_four_parents_received_all_programme_reminders
    EnqueueSchoolConsentRemindersJob.new.perform
    Sidekiq::Job.drain_all

    parent_emails.each do |email|
      reminder_templates.each do |template|
        expect(email_deliveries).to include(
          matching_notify_email(to: email, template:)
        )
      end
    end

    parent_phones.each do |phone|
      expect_sms_to(phone, :consent_school_reminder, :any)
    end

    mmrv_parent_emails.each do |email|
      expect(email_deliveries).to include(
        matching_notify_email(
          to: email,
          template: :consent_school_reminder_mmrv
        )
      )
    end

    mmrv_parent_phones.each do |phone|
      expect_sms_to(phone, :consent_school_reminder, :any)
    end
  end
end
