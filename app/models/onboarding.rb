# frozen_string_literal: true

class Onboarding
  include ActiveModel::Model

  CLINIC_ATTRIBUTES = {
    point_of_care: %i[
      address_line_1
      address_line_2
      address_postcode
      address_town
      name
      ods_code
      url
      year_groups
    ],
    national_reporting: []
  }.freeze

  ORGANISATION_ATTRIBUTES = {
    point_of_care: %i[ods_code],
    national_reporting: %i[ods_code]
  }.freeze

  TEAM_ATTRIBUTES = {
    point_of_care: %i[
      careplus_staff_code
      careplus_staff_type
      careplus_venue_code
      days_before_consent_reminders
      days_before_consent_requests
      email
      name
      phone
      phone_instructions
      privacy_notice_url
      privacy_policy_url
      reply_to_id
      type
      workgroup
    ],
    national_reporting: %i[name type workgroup national_reporting_cut_off_date]
  }.freeze

  SUBTEAM_ATTRIBUTES = {
    point_of_care: %i[email name phone phone_instructions reply_to_id],
    national_reporting: []
  }.freeze

  USER_ATTRIBUTES = {
    point_of_care: %i[email fallback_role family_name given_name password],
    national_reporting: %i[email fallback_role family_name given_name password]
  }.freeze

  DEFAULT_PROGRAMMES = {
    point_of_care: [],
    national_reporting: %w[flu hpv]
  }.freeze

  validates :team, presence: true
  validates :programmes, presence: true
  with_options if: -> { team.has_national_reporting_access? } do
    validates :subteams, absence: true
    validates :schools, absence: true
    validates :clinics, absence: true
  end
  with_options unless: -> { team.has_national_reporting_access? } do
    validates :subteams, presence: true
    validates :schools, presence: true
    validates :clinics, presence: true
  end
  validate :no_duplicate_urns_across_school_types
  validate :no_schools_with_existing_team_attachments

  def initialize(hash)
    config = hash.deep_symbolize_keys

    team_type = config.fetch(:team, {})&.fetch(:type, "point_of_care")&.to_sym

    @organisation =
      Organisation.find_or_initialize_by(
        config.fetch(:organisation, {}).slice(
          *ORGANISATION_ATTRIBUTES.fetch(team_type)
        )
      )

    @team =
      Team.new(
        **config.fetch(:team, {}).slice(*TEAM_ATTRIBUTES.fetch(team_type)),
        organisation: @organisation,
        programme_types: []
      )

    @programmes =
      config
        .fetch(:programmes, DEFAULT_PROGRAMMES.fetch(team_type, []))
        .map { |type| ExistingProgramme.new(type:, team:) }

    subteams_by_name =
      config
        .fetch(:subteams, {})
        .transform_values { it.slice(*SUBTEAM_ATTRIBUTES.fetch(team_type)) }
        .transform_values { Subteam.new(**it, team:) }

    @subteams = subteams_by_name.values

    @users =
      config
        .fetch(:users, [])
        .map { it.slice(*USER_ATTRIBUTES.fetch(team_type)) }
        .map do |attributes|
          User
            .find_or_initialize_by(email: attributes[:email])
            .tap { it.assign_attributes(attributes) }
        end

    @schools =
      config
        .fetch(:schools, {})
        .flat_map do |team_name, schools|
          subteam = subteams_by_name[team_name]
          schools.map do |config|
            if config.is_a?(Hash)
              urn = config.fetch(:urn)
              name = config.fetch(:name, nil)
              site = config.fetch(:site, nil)
              address_line_1 = config.fetch(:address_line_1, nil)
              address_line_2 = config.fetch(:address_line_2, nil)
              address_town = config.fetch(:address_town, nil)
              address_postcode = config.fetch(:address_postcode, nil)
              NewSchoolSite.new(
                urn:,
                name:,
                site:,
                address_line_1:,
                address_line_2:,
                address_town:,
                address_postcode:,
                subteam:,
                programmes:
              )
            else
              urn = config
              ExistingSchool.new(urn:, subteam:, programmes:)
            end
          end
        end

    @clinics =
      config
        .fetch(:clinics, {})
        .each_with_object({}) do |(team_name, clinic_configs), hash|
          subteam = subteams_by_name[team_name]
          clinic_configs
            .map { it.slice(*CLINIC_ATTRIBUTES.fetch(team_type)) }
            .each do
              hash[Location.new(**it, type: :community_clinic)] = subteam
            end
        end
  end

  def no_duplicate_urns_across_school_types
    existing_school_urns =
      schools.select { it.is_a?(ExistingSchool) }.map(&:urn)

    site_urns = schools.select { it.is_a?(NewSchoolSite) }.map(&:urn)

    overlapping_urns = existing_school_urns & site_urns

    if overlapping_urns.any?
      errors.add(
        :schools,
        "URN(s) #{overlapping_urns.join(", ")} cannot appear as both a regular school and a site"
      )
    end
  end

  def no_schools_with_existing_team_attachments
    schools.each_with_index do |school, index|
      urn = school.urn
      next if urn.blank?

      locations_with_teams =
        Location.gias_school.where(urn:).joins(:teams).distinct

      next unless locations_with_teams.exists?

      site_codes = locations_with_teams.pluck(:site).compact.sort
      team_names =
        locations_with_teams.flat_map { it.teams.pluck(:name) }.uniq.sort

      message =
        if site_codes.any?
          "URN #{urn} has sites (#{site_codes.join(", ")}) already attached to teams: #{team_names.join(", ")}"
        else
          "URN #{urn} is already attached to teams: #{team_names.join(", ")}"
        end

      errors.add("school.#{index}.urn", message)
    end
  end

  def valid?(context = nil)
    ([super] + models.map(&:valid?)).all?
  end

  def invalid?(context = nil)
    ([super] + models.map(&:invalid?)).any?
  end

  def errors
    super.tap do |errors|
      merge_errors_from([organisation], errors:, name: "organisation")
      merge_errors_from([team], errors:, name: "team")
      merge_errors_from(programmes, errors:, name: "programme")
      merge_errors_from(subteams, errors:, name: "subteam")
      merge_errors_from(users, errors:, name: "user")
      merge_errors_from(schools, errors:, name: "school")
      merge_errors_from(clinics.keys, errors:, name: "clinic")
    end
  end

  def save!(include_previous_academic_year: false)
    academic_years = [AcademicYear.pending]

    academic_years << AcademicYear.pending - 1 if include_previous_academic_year

    ActiveRecord::Base.transaction do
      models.each(&:save!)

      academic_years.each do |academic_year|
        schools.each { |school| school.attach_to_team!(academic_year:) }

        clinics.each do |clinic, subteam|
          clinic.attach_to_team!(team, academic_year:, subteam:)
        end
      end

      # Reload to ensure the programmes are loaded.
      team.reload

      @users.each { |user| user.teams << team }

      academic_years.each do |academic_year|
        GenericLocationFactory.call(team:, academic_year:)
      end

      PatientTeamUpdater.call(team_scope: Team.where(id: team.id))
    end
  end

  private

  attr_reader :organisation,
              :team,
              :programmes,
              :subteams,
              :users,
              :schools,
              :clinics

  def models
    [organisation] + [team] + programmes + subteams + users + schools +
      clinics.keys
  end

  def merge_errors_from(objects, errors:, name:)
    objects.each_with_index do |obj, index|
      obj.errors.each do |error|
        prefix =
          if objects.count == 1
            name
          else
            "#{name}.#{index}"
          end

        errors.import(error, attribute: "#{prefix}.#{error.attribute}")
      end
    end
  end

  class ExistingProgramme
    include ActiveModel::Model

    attr_accessor :type, :team

    validates :programme, presence: true

    def programme
      @programme ||= Programme.find(type)
    end

    def save!
      team.update!(programme_types: (team.programme_types + [type]).sort.uniq)
    end
  end

  class ExistingSchool
    include ActiveModel::Model

    attr_accessor :urn, :subteam, :programmes

    validates :location, presence: true
    validates :subteam, presence: true
    validates :status, inclusion: %w[open opening]

    def location
      @location ||= Location.gias_school.find_by_urn_and_site(urn)
    end

    delegate :status, to: :location, allow_nil: true
    delegate :team, to: :subteam

    def save!
      # Does nothing
    end

    def attach_to_team!(academic_year:)
      location.attach_to_team!(team, academic_year:, subteam:)
      location.import_year_groups_from_gias!(academic_year:)
      location.import_default_programme_year_groups!(
        programmes.map(&:programme),
        academic_year:
      )
    end
  end

  class NewSchoolSite
    include ActiveModel::Model

    attr_accessor :urn,
                  :name,
                  :site,
                  :address_line_1,
                  :address_line_2,
                  :address_town,
                  :address_postcode,
                  :subteam,
                  :programmes

    validates :location, presence: true
    validates :subteam, presence: true
    validates :status, inclusion: %w[open opening]
    validates :name, presence: true
    validates :site, presence: true

    def original_location
      @original_location ||= Location.gias_school.find_by_urn_and_site(urn)
    end

    def location
      return nil unless original_location

      @location ||=
        original_location.dup.tap do |loc|
          loc.assign_attributes(
            {
              name:,
              site:,
              address_line_1:,
              address_line_2:,
              address_town:,
              address_postcode:
            }.compact
          )
        end
    end

    delegate :status, to: :location, allow_nil: true
    delegate :team, to: :subteam

    delegate :save!, to: :location

    def attach_to_team!(academic_year:)
      location.attach_to_team!(team, academic_year:, subteam:)
      location.import_year_groups_from_gias!(academic_year:)
      location.import_default_programme_year_groups!(
        programmes.map(&:programme),
        academic_year:
      )
    end
  end
end
