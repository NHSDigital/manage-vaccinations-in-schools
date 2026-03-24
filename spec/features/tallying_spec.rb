# frozen_string_literal: true

describe "Tallying" do
  scenario "vaccinator can see how many they have administered during a session" do
    given_a_session_for_hpv_and_flu_is_running_today
    and_i_have_administered_two_cervarix_vaccines_for_hpv_programme
    and_administered_one_gardasil_vaccine_for_hpv_programme
    and_administered_one_fluenz_vaccine_for_flu_programme
    and_i_created_vaccination_records_yesterday
    and_vaccinations_are_recorded_by_other_team_members
    and_the_default_vaccine_batches_have_been_set_for_flu_and_hpv

    when_i_visit_the_session_record_tab
    and_i_click_on_the_expander_your_vaccinations_today
    then_i_see_my_vaccination_tallies_for_today_with_default_batches
  end

  scenario "no vaccinations have been administered yet" do
    given_a_session_for_hpv_and_flu_is_running_today
    and_the_default_vaccine_batches_have_been_set_for_flu_and_hpv

    when_i_visit_the_session_record_tab
    and_i_click_on_the_expander_your_vaccinations_today
    then_i_see_my_vaccination_tallies_with_all_zero_values_with_default_batches
  end

  scenario "when an admin is viewing the record tab for a session" do
    given_a_session_for_hpv_and_flu_is_running_today
    when_i_visit_the_session_record_tab_as_an_admin
    then_i_do_not_see_the_vaccination_tallies_table
  end

  def given_a_session_for_hpv_and_flu_is_running_today
    @flu_programme = Programme.flu
    @hpv_programme = Programme.hpv

    programmes = [@hpv_programme, @flu_programme]
    team = create(:team, :with_one_nurse, programmes:)
    @user = team.users.first

    @session =
      create(:session, :today, :requires_no_registration, programmes:, team:)

    @cervarix_vaccine = @hpv_programme.vaccines.find_by!(brand: "Cervarix")
    @cervarix_batch = create(:batch, :not_expired, vaccine: @cervarix_vaccine)

    @gardasil9_vaccine = @hpv_programme.vaccines.find_by!(brand: "Gardasil 9")
    @gardasil9_batch = create(:batch, :not_expired, vaccine: @gardasil9_vaccine)

    @fluenz_vaccine = @flu_programme.vaccines.find_by!(brand: "Fluenz")
    @fluenz_batch = create(:batch, :not_expired, vaccine: @fluenz_vaccine)

    @patient =
      create(
        :patient,
        :consent_given_triage_not_needed,
        :in_attendance,
        session: @session
      )
  end

  def when_i_visit_the_session_record_tab
    sign_in @user, role: :nurse
    visit session_record_path(@session)
  end

  def when_i_visit_the_session_record_tab_as_an_admin
    sign_in @user, role: :medical_secretary
    visit session_record_path(@session)
  end

  def and_click_on_change_default_batch_link
    within ".nhsuk-table" do
      click_on "Change"
    end
  end

  def and_the_default_vaccine_batches_have_been_set_for_flu_and_hpv
    page.set_rack_session(
      todays_batch: {
        @hpv_programme.type.to_s => {
          @cervarix_vaccine.method => {
            id: @cervarix_batch.id,
            date: Date.current.iso8601
          }
        },
        @flu_programme.type.to_s => {
          @fluenz_vaccine.method => {
            id: @fluenz_batch.id,
            date: Date.current.iso8601
          }
        }
      }
    )
  end

  def and_i_have_administered_two_cervarix_vaccines_for_hpv_programme
    create(
      :vaccination_record,
      batch: @cervarix_batch,
      vaccine: @cervarix_vaccine,
      session: @session,
      programme: @hpv_programme,
      performed_by: @user
    )

    create(
      :vaccination_record,
      batch: @gardasil9_batch,
      vaccine: @gardasil9_vaccine,
      session: @session,
      programme: @hpv_programme,
      performed_by: @user
    )
  end

  def and_administered_one_gardasil_vaccine_for_hpv_programme
    create(
      :vaccination_record,
      batch: @gardasil9_batch,
      vaccine: @gardasil9_vaccine,
      session: @session,
      programme: @hpv_programme,
      performed_by: @user
    )
  end

  def and_administered_one_fluenz_vaccine_for_flu_programme
    create(
      :vaccination_record,
      batch: @fluenz_batch,
      vaccine: @fluenz_vaccine,
      session: @session,
      programme: @flu_programme,
      performed_by: @user
    )
  end

  def and_i_created_vaccination_records_yesterday
    create(
      :vaccination_record,
      batch: @cervarix_batch,
      vaccine: @cervarix_vaccine,
      session: @session,
      programme: @hpv_programme,
      performed_by: @user,
      performed_at: Time.zone.yesterday
    )
  end

  def and_vaccinations_are_recorded_by_other_team_members
    create(
      :vaccination_record,
      batch: @cervarix_batch,
      vaccine: @cervarix_vaccine,
      session: @session,
      programme: @hpv_programme
    )
  end

  def then_i_see_my_vaccination_tallies_for_today_with_default_batches
    expect(page).to have_content("Fluenz 1 #{@fluenz_batch.number} Change")
    expect(page).to have_content("Gardasil 9 2 Not set")
    expect(page).to have_content("Cervarix 1 #{@cervarix_batch.number} Change")
  end

  def then_i_see_my_vaccination_tallies_with_all_zero_values_with_default_batches
    expect(page).to have_content("Fluenz 0 #{@fluenz_batch.number} Change")
    expect(page).to have_content("Gardasil 9 0 Not set")
  end

  def and_i_click_on_the_expander_your_vaccinations_today
    find("span", text: "Your vaccinations today").click
  end

  def then_i_do_not_see_the_vaccination_tallies_table
    expect(page).to have_no_content("Your vaccinations today")
  end
end
