# frozen_string_literal: true

describe "Session school reminders" do
  scenario "parents with consent given receive a reminder the day before a session" do
    given_a_school_session_is_scheduled_for_tomorrow
    and_a_patient_has_given_consent

    when_school_session_reminders_are_sent

    then_the_consenting_parent_receives_an_email_reminder
    and_the_consenting_parent_receives_an_sms_reminder
  end

  def given_a_school_session_is_scheduled_for_tomorrow
    programme = Programme.hpv
    @team = create(:team, programmes: [programme])
    school = create(:gias_school, team: @team)
    @session =
      create(
        :session,
        date: Date.tomorrow,
        team: @team,
        programmes: [programme],
        location: school
      )
  end

  def and_a_patient_has_given_consent
    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        session: @session,
        team: @team,
        programmes: @session.programmes
      )
    @parent = @patient.consents.first.parent
  end

  def when_school_session_reminders_are_sent
    EnqueueSchoolSessionRemindersJob.perform_now
    perform_enqueued_jobs
    Sidekiq::Job.drain_all
  end

  def then_the_consenting_parent_receives_an_email_reminder
    expect(email_deliveries).to include(
      matching_notify_email(
        to: @parent.email,
        template: :session_school_reminder
      ).with_content_including("quick reminder", "haven’t already told")
    )
  end

  def and_the_consenting_parent_receives_an_sms_reminder
    expect(sms_deliveries).to include(
      matching_notify_sms(
        phone_number: @parent.phone,
        template: :session_school_reminder
      ).with_content_including("may get their", "at school on")
    )
  end
end
