# frozen_string_literal: true

if Settings.disallow_database_seeding
  Rails.logger.info "Database seeding is disabled"
  exit
end

Faker::Config.locale = "en-GB"

def set_feature_flags
  FeatureFlagFactory.call
  FeatureFlagFactory.enable_for_development!(check_rails_env: false)
end

def seed_vaccines
  Rake::Task["vaccines:seed"].execute
end

def create_gp_practices
  Location.import!(FactoryBot.build_list(:gp_practice, 30))
end

def create_team(ods_code:, workgroup: nil, type: :point_of_care)
  workgroup ||= ods_code.downcase

  Team.find_by(workgroup:) ||
    FactoryBot.create(
      :team,
      :with_careplus_enabled,
      ods_code:,
      programmes: Programme.all,
      workgroup:,
      type:
    )
end

def create_user(role, team:, email: nil, uid: nil)
  if uid
    User.find_by(uid:) ||
      FactoryBot.create(
        role,
        uid:,
        family_name: "Flo",
        given_name: "Nurse",
        email: "nurse.flo@example.nhs.uk",
        provider: "cis2",
        team:
        # password: Do not set this as they should not log in via password
      )
  elsif email
    User.find_by(email:) ||
      FactoryBot.create(
        role,
        family_name: email.split("@").first.split(".").last.capitalize,
        given_name: email.split("@").first.split(".").first.capitalize,
        email:,
        password: email,
        team:
      )
  else
    raise "No email or UID provided"
  end
end

def create_community_clinics(team)
  FactoryBot.create_list(:community_clinic, 5, team:)
end

def create_generic_clinic_session(user, team)
  session =
    create_session(
      user,
      team,
      location: team.generic_clinic,
      programmes: [Programme.menacwy, Programme.td_ipv],
      in_the_future: true,
      year_groups: []
    )

  FactoryBot.create(
    :patient,
    :consent_given_triage_not_needed,
    :in_attendance,
    session:
  )
end

def create_session(
  user,
  team,
  programmes:,
  location: nil,
  completed: false,
  in_the_future: false,
  year_groups: nil
)
  year_groups ||= programmes.flat_map(&:default_year_groups).uniq

  Batch.import!(
    Vaccine
      .active
      .for_programmes(programmes)
      .find_each
      .map { |vaccine| FactoryBot.build(:batch, :not_expired, team:, vaccine:) }
  )

  location ||=
    FactoryBot.create(:gias_school, team:, gias_year_groups: year_groups)
  date =
    if completed
      1.week.ago.to_date
    elsif in_the_future
      1.month.from_now.to_date
    else
      Date.current
    end

  academic_year = AcademicYear.current

  dates =
    [date - 1.day, date, date + 1.day].select do |value|
      value.in?(academic_year.to_academic_year_date_range)
    end

  session =
    FactoryBot.create(
      :session,
      academic_year:,
      dates:,
      team:,
      programmes:,
      location:
    )

  programmes.each do |programme|
    year_groups.each do |year_group|
      patients_without_consent =
        FactoryBot.create_list(
          :patient,
          2,
          programmes: [programme],
          session:,
          performed_by: user,
          year_group:
        )

      patients_without_consent.each do |patient|
        FactoryBot.create(
          :consent_form,
          :recorded,
          given_name: patient.given_name,
          family_name: patient.family_name,
          session:
        )
      end

      # Add extra consent forms with a successful NHS number lookup
      temporary_patient = FactoryBot.build(:patient)
      FactoryBot.create(
        :consent_form,
        :recorded,
        given_name: temporary_patient.given_name,
        family_name: temporary_patient.family_name,
        nhs_number: temporary_patient.nhs_number,
        session:
      )

      traits = %i[
        consent_conflicting
        consent_given_triage_needed
        consent_given_triage_not_needed
        needs_consent_no_contact_details
        consent_refused
        consent_given_triage_delay_vaccination
        consent_given_triage_safe_to_vaccinate
        unable_to_vaccinate
        vaccinated
      ]

      traits << :partially_vaccinated_triage_needed if programme.td_ipv?

      traits.each do |trait|
        patient =
          FactoryBot.create(
            :patient,
            trait,
            programmes: [programme],
            session:,
            performed_by: user,
            year_group:,
            parents: [FactoryBot.create(:parent)]
          )

        next if in_the_future

        FactoryBot.create(
          :consent_notification,
          :request,
          patient:,
          session:,
          programmes: [programme],
          sent_at: session.send_consent_requests_at
        )
      end
    end
  end

  session
end

def create_home_educated_or_unknown_school_patients(team)
  team.generic_schools.each do |school|
    3.times do
      parents = FactoryBot.create_list(:parent, rand(1..2))
      FactoryBot.create(:patient, school:, location: school, parents:)
    end
  end
end

def create_imports(user, team)
  %i[pending invalid processed].each do |status|
    FactoryBot.create(:cohort_import, status, team:, uploaded_by: user)
    FactoryBot.create(:immunisation_import, status, team:, uploaded_by: user)
    FactoryBot.create(
      :class_import,
      status,
      team:,
      session: team.sessions.includes(:location).first,
      uploaded_by: user
    )
  end

  low_pds_import =
    FactoryBot.create(
      :cohort_import,
      :low_pds_match_rate,
      team:,
      uploaded_by: user
    )
  FactoryBot.create_list(
    :patient_changeset,
    15,
    import: low_pds_import,
    pds_nhs_number: nil
  )
end

def create_national_reporting_imports(user, team)
  %i[pending invalid processed].each do |status|
    FactoryBot.create(
      :immunisation_import,
      status,
      type: "national_reporting",
      team:,
      uploaded_by: user
    )
  end
end

def create_school_moves(team)
  patients = team.patients.sample(10)

  patients.each do |patient|
    if [true, false].sample
      FactoryBot.create(:school_move, :to_home_educated, patient:, team:)
    else
      FactoryBot.create(
        :school_move,
        :to_school,
        patient:,
        school: team.gias_schools.sample
      )
    end
  end
end

def create_team_sessions(user, team)
  flu = Programme.flu
  hpv = Programme.hpv
  menacwy = Programme.menacwy
  td_ipv = Programme.td_ipv

  # Flu-only sessions
  create_session(user, team, programmes: [flu])
  create_session(user, team, programmes: [flu], completed: true)
  create_session(user, team, programmes: [flu], in_the_future: true)

  # HPV-only sessions
  create_session(user, team, programmes: [hpv])
  create_session(user, team, programmes: [hpv], completed: true)
  create_session(user, team, programmes: [hpv], in_the_future: true)

  # MenACWY and Td/IPV combined sessions
  create_session(
    user,
    team,
    programmes: [menacwy, td_ipv],
    completed: false,
    year_groups: [8, 9, 10]
  )

  # All three vaccines combined
  create_session(
    user,
    team,
    programmes: [menacwy, td_ipv, hpv],
    completed: false,
    year_groups: [8, 9, 10]
  )
end

def create_nurse_joy_team
  team = create_team(ods_code: "R1L")
  user = create_user(:nurse, team:, email: "nurse.joy@example.com")
  create_user(:medical_secretary, team:, email: "admin.hope@example.com")
  create_user(:superuser, team:, email: "superuser@example.com")
  create_user(:healthcare_assistant, team:, email: "hca@example.com")
  create_user(:prescriber, team:, email: "prescriber@example.com")

  Audited
    .audit_class
    .as_user(user) do
      create_community_clinics(team)
      create_generic_clinic_session(user, team)
      create_team_sessions(user, team)
      create_home_educated_or_unknown_school_patients(team)
      create_imports(user, team)
      create_school_moves(team)
    end
end

def create_upload_patients_and_vaccination_records(user)
  patients =
    FactoryBot.create_list(:patient, 50, :archived, team: user.teams.first)

  immunisation_import =
    ImmunisationImport.find_by(type: "national_reporting", status: "processed")

  patients.each do |patient|
    FactoryBot.create(
      :vaccination_record,
      :sourced_from_national_reporting,
      immunisation_import:,
      patient:,
      performed_by: user
    )
  end
end

def create_national_reporting_team
  team =
    FactoryBot.create(
      :team,
      :national_reporting,
      ods_code: "XX99",
      programmes: [Programme.flu, Programme.hpv],
      workgroup: "XX99"
    )
  user =
    create_user(:medical_secretary, team:, email: "admin.sarah@example.com")
  create_user(:superuser, team:, email: "superuser.rob@example.com")

  create_national_reporting_imports(user, team)

  create_upload_patients_and_vaccination_records(user)
end

def create_a9a5a_team
  # CIS2 team - the ODS code and user UID need to match the values in the CIS2 env
  team = create_team(ods_code: "A9A5A")
  user = create_user(:nurse, team:, uid: "555057896106")

  Audited
    .audit_class
    .as_user(user) do
      create_community_clinics(team)
      create_team_sessions(user, team)
      create_home_educated_or_unknown_school_patients(team)
      create_imports(user, team)
      create_school_moves(team)
    end
end

def create_support_team
  workgroup = CIS2Info::SUPPORT_WORKGROUP

  support_team =
    FactoryBot.create(
      :team,
      :support,
      ods_code: CIS2Info.support_organisation,
      workgroup:,
      programmes: Programme.all
    )
  create_user(:support, team: support_team, email: "support@example.com")
end

set_feature_flags

seed_vaccines
create_gp_practices
create_support_team

if Settings.cis2.enabled
  create_a9a5a_team
else
  create_nurse_joy_team
  create_national_reporting_team
end

PatientTeamUpdater.call
PatientStatusUpdater.call

Rake::Task["smoke:seed"].execute
