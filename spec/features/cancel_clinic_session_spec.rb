# frozen_string_literal: true

describe "Cancel clinic session" do
  around { |example| travel_to(Date.new(2026, 4, 1)) { example.run } }
  before { Flipper.enable(:clinic_sessions) }
  after { Flipper.disable(:clinic_sessions) }

  scenario "cancelling a future clinic session notifies all parents" do
    given_a_future_clinic_session_exists
    and_children_are_booked_with_parents

    when_i_visit_the_session_page
    and_i_click_on_cancel_session

    then_i_see_the_cancel_confirmation_page
    and_i_confirm_the_session_cancellation

    then_i_see_the_session_has_been_cancelled
    and_the_session_is_marked_as_cancelled
    and_all_parents_receive_a_cancellation_notification
  end

  def given_a_future_clinic_session_exists
    given_a_team_and_user_exist

    @session =
      create(
        :session,
        :scheduled,
        team: @team,
        location: @location,
        programmes: [@programme],
        date: Date.new(2026, 4, 28)
      )
  end

  def given_a_team_and_user_exist
    @programme = Programme.flu
    @team = create(:team, :with_one_nurse, programmes: [@programme])
    @user = @team.users.first
    @location = create(:generic_clinic, team: @team, programmes: [@programme])
  end

  def and_children_are_booked_with_parents
    @first_parent = create(:parent, email: "first.parent@example.com")
    @second_parent = create(:parent, email: "second.parent@example.com")

    @first_patient =
      create(
        :patient,
        session: @session,
        parents: [@first_parent],
        year_group: 8
      )

    @second_patient =
      create(
        :patient,
        session: @session,
        parents: [@second_parent],
        year_group: 8
      )

    create(
      :consent,
      :given,
      patient: @first_patient,
      parent: @first_parent,
      programme: @programme,
      team: @team
    )

    create(
      :consent,
      :given,
      patient: @second_patient,
      parent: @second_parent,
      programme: @programme,
      team: @team
    )
  end

  def when_i_visit_the_session_page
    sign_in @user
    visit session_path(@session)
  end

  def and_i_click_on_cancel_session
    click_on "Cancel session"
  end

  def then_i_see_the_cancel_confirmation_page
    expect(page).to have_content(
      "Are you sure you want to cancel this session?"
    )
    expect(page).to have_content("2 children are booked for this session.")
  end

  def and_i_confirm_the_session_cancellation
    click_on "Yes, cancel this session"
  end

  def then_i_see_the_session_has_been_cancelled
    expect(page).to have_current_path("/sessions")
    expect(page).to have_content(
      "Flu clinic at Community clinic on 28 April 2026 cancelled"
    )
    expect(page).not_to have_link("Community clinic")
  end

  def and_the_session_is_marked_as_cancelled
    expect(@session.reload.cancelled?).to be(true)
  end

  def and_all_parents_receive_a_cancellation_notification
    expect(email_deliveries.count).to eq(2)

    expect(email_deliveries).to include(
      matching_notify_email(
        to: @first_parent.email,
        template: :session_clinic_cancelled
      ).with_content_including("has been cancelled")
    )

    expect(email_deliveries).to include(
      matching_notify_email(
        to: @second_parent.email,
        template: :session_clinic_cancelled
      ).with_content_including("has been cancelled")
    )
  end
end
