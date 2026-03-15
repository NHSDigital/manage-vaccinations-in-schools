# frozen_string_literal: true

describe "Schools" do
  scenario "Filtering on schools and viewing sessions" do
    given_a_team_exists_with_a_few_schools
    and_i_am_signed_in

    when_i_visit_the_dashboard
    then_i_can_see_the_schools_link

    when_i_click_on_the_schools_link
    then_i_see_both_schools
    and_i_can_see_the_unknown_school

    when_i_filter_on_primary_schools
    then_i_see_only_the_primary_school

    when_i_filter_on_secondary_schools
    then_i_see_only_the_secondary_school

    when_i_click_on_the_secondary_school
    then_i_see_the_secondary_patients

    when_i_click_on_sessions
    then_i_see_the_secondary_sessions

    when_i_click_on_edit_session
    and_i_click_on_back
    then_i_see_the_secondary_sessions
  end

  scenario "Sending clinic invitations to children in no known school" do
    given_a_team_with_no_known_school_children
    and_i_am_signed_in

    when_i_visit_the_schools_page
    and_i_click_on_no_known_school
    then_i_see_the_send_invitations_button

    when_i_click_send_clinic_invitations
    then_i_should_see_programmes_i_can_send_invitations_for
    and_i_select_programmes_and_send
    then_i_see_the_invitation_confirmation
    and_the_parents_receive_invitations

    when_i_click_send_clinic_invitations
    then_i_see_no_invitations_need_to_be_sent
  end

  def given_a_team_exists_with_a_few_schools
    programmes = [Programme.flu, Programme.hpv]

    @team = create(:team, programmes:)

    @primary_school = create(:school, :primary, team: @team)
    @secondary_school = create(:school, :secondary, team: @team)

    @primary_session =
      create(:session, :yesterday, location: @primary_school, team: @team)
    @secondary_session =
      create(:session, :tomorrow, location: @secondary_school, team: @team)

    @primary_patient =
      create(:patient, year_group: 1, session: @primary_session)
    @secondary_patient =
      create(:patient, year_group: 7, session: @secondary_session)

    @patient_in_both_schools = create(:patient, school: @secondary_school)
    create(
      :patient_location,
      patient: @patient_in_both_schools,
      session: @primary_session
    )

    @nurse = create(:nurse, team: @team)
  end

  def and_i_am_signed_in = sign_in @nurse

  def when_i_visit_the_dashboard
    visit dashboard_path
  end

  def then_i_can_see_the_schools_link
    expect(page).to have_link("Schools").twice
  end

  def when_i_click_on_the_schools_link
    click_link "Schools", match: :first
  end

  def then_i_see_both_schools
    expect(page).to have_content(@primary_school.name)
    expect(page).to have_content("Children1 child")
    expect(page).to have_content(@secondary_school.name)
    expect(page).to have_content("Children2 children")
  end

  def and_i_can_see_the_unknown_school
    expect(page).to have_content("Unknown school")
  end

  def when_i_filter_on_primary_schools
    choose "Primary"
    click_on "Update results"
  end

  def then_i_see_only_the_primary_school
    expect(page).to have_content(@primary_school.name)
    expect(page).not_to have_content(@secondary_school.name)
  end

  def when_i_filter_on_secondary_schools
    choose "Secondary"
    click_on "Update results"
  end

  def then_i_see_only_the_secondary_school
    expect(page).not_to have_content(@primary_school.name)
    expect(page).to have_content(@secondary_school.name)
  end

  def when_i_click_on_the_secondary_school
    click_on @secondary_school.name
  end

  def then_i_see_the_secondary_patients
    expect(page).not_to have_content(@primary_patient.full_name)
    expect(page).to have_content(@secondary_patient.full_name)
  end

  def when_i_click_on_sessions
    within ".app-secondary-navigation" do
      click_on "Sessions"
    end
  end

  def then_i_see_the_secondary_sessions
    expect(page).to have_content("Scheduled sessions")
    expect(page).to have_content(Date.tomorrow.to_fs(:long))
  end

  def when_i_click_on_edit_session
    click_on "Edit session"
  end

  def and_i_click_on_back
    click_on "Back"
  end

  def given_a_team_with_no_known_school_children
    programmes = [Programme.hpv]
    @team = create(:team, programmes:)

    @patients =
      10.times.map do
        create(
          :patient,
          :consent_no_response,
          team: @team,
          school: @team.unknown_school,
          parents: [build(:parent)],
          programmes:,
          location: @team.unknown_school,
          academic_year: AcademicYear.pending
        )
      end

    # We create these to ensure these children aren't invited.

    # No parent contact details
    create(
      :patient,
      :consent_no_response,
      team: @team,
      school: @team.unknown_school,
      parents: [],
      programmes:,
      location: @team.unknown_school,
      academic_year: AcademicYear.pending
    )

    # Refused consent
    create(
      :patient,
      :consent_refused,
      team: @team,
      school: @team.unknown_school,
      parents: [build(:parent)],
      programmes:,
      location: @team.unknown_school,
      academic_year: AcademicYear.pending
    )

    # Conflicting consent
    create(
      :patient,
      :consent_conflicting,
      team: @team,
      school: @team.unknown_school,
      parents: [build(:parent)],
      programmes:,
      location: @team.unknown_school,
      academic_year: AcademicYear.pending
    )

    # Archived
    create(
      :patient,
      :consent_no_response,
      :archived,
      team: @team,
      school: @team.unknown_school,
      parents: [build(:parent)],
      programmes:,
      location: @team.unknown_school,
      academic_year: AcademicYear.pending
    )

    @nurse = create(:nurse, team: @team)
  end

  def when_i_visit_the_schools_page
    visit schools_path
  end

  def and_i_click_on_no_known_school
    click_on "Unknown school"
  end

  def then_i_see_the_send_invitations_button
    expect(page).to have_content("Send clinic invitations")
  end

  def when_i_click_send_clinic_invitations
    click_on "Send clinic invitations"
  end

  def then_i_should_see_programmes_i_can_send_invitations_for
    expect(page).to have_content(
      "10 children have not been invited to a clinic yet"
    )
  end

  def and_i_select_programmes_and_send
    check "HPV"
    click_on "Send clinic invitations"
  end

  def then_i_see_the_invitation_confirmation
    expect(page).to have_content("10 children invited to the clinic")
  end

  def and_the_parents_receive_invitations
    perform_enqueued_jobs

    expect(email_deliveries.count).to eq(@patients.count)

    @patients.each do |patient|
      patient.parents.each do |parent|
        expect_email_to parent.email, :clinic_initial_invitation, :any
      end
    end
  end

  def then_i_see_no_invitations_need_to_be_sent
    expect(page).to have_content(
      "You do not need to send any clinic invitations."
    )
  end
end
