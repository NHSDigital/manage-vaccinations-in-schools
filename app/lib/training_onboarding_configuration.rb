# frozen_string_literal: true

class TrainingOnboardingConfiguration
  def initialize(ods_code:, workgroup:, type:)
    @ods_code = ods_code
    @workgroup = workgroup
    @type = type
  end

  def call
    if type == "national_reporting"
      { organisation:, team:, users: }
    else
      {
        organisation:,
        team:,
        programmes:,
        subteams:,
        users:,
        schools:,
        clinics:
      }
    end
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :ods_code, :workgroup, :type

  def academic_year = AcademicYear.pending

  def identifier = "#{ods_code} (#{workgroup})"

  def name = "#{identifier} training"

  def email = "#{workgroup}@example.com"

  def phone = "07700 900815"

  def organisation
    { ods_code: }
  end

  def team
    if type == "national_reporting"
      { name:, workgroup:, type: }
    else
      {
        workgroup:,
        name:,
        email:,
        phone:,
        careplus_venue_code: ods_code,
        privacy_notice_url: "https://example.com/privacy-notice-#{workgroup}",
        privacy_policy_url: "https://example.com/privacy-policy-#{workgroup}",
        type:
      }
    end
  end

  def programmes = Programme.all.map(&:type)

  def subteams
    { generic: { name:, email:, phone: } }
  end

  def users
    return [] if Settings.cis2.enabled

    User.fallback_roles.keys.map do |role|
      email_and_password = "#{role.dasherize}.#{workgroup}@example.com"

      {
        email: email_and_password,
        password: email_and_password,
        given_name: role.humanize,
        family_name: identifier,
        fallback_role: role
      }
    end
  end

  def schools
    scope =
      Location
        .gias_school
        .open
        .without_team(academic_year:)
        .order("RANDOM()")
        .limit(10)

    # Make sure we get a good mix of primary and secondary schools.
    primary_schools = scope.has_gias_year_groups([1, 2, 3, 4, 5, 6]).pluck(:urn)
    secondary_schools =
      scope.has_gias_year_groups([7, 8, 9, 10, 11]).pluck(:urn)

    { generic: primary_schools + secondary_schools }
  end

  def clinics
    {
      generic: [
        {
          name: "Training #{identifier} clinic",
          address_line_1: "Training clinic way",
          address_town: "Training town",
          address_postcode: "SW1A 1AA"
        }
      ]
    }
  end
end
