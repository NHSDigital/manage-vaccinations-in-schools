# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id                        :bigint           not null, primary key
#  address_line_1            :text
#  address_line_2            :text
#  address_postcode          :text
#  address_town              :text
#  gias_establishment_number :integer
#  gias_local_authority_code :integer
#  gias_phase                :integer
#  gias_year_groups          :integer          default([]), not null, is an Array
#  name                      :text             not null
#  ods_code                  :string
#  site                      :string
#  status                    :integer          default("unknown"), not null
#  systm_one_code            :string
#  type                      :integer          not null
#  url                       :text
#  urn                       :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_locations_on_ods_code        (ods_code) UNIQUE
#  index_locations_on_systm_one_code  (systm_one_code) UNIQUE
#  index_locations_on_urn             (urn) UNIQUE WHERE ((type = 0) AND (site IS NULL))
#  index_locations_on_urn_and_site    (urn,site) UNIQUE
#
class Location < ApplicationRecord
  self.inheritance_column = nil

  include AddressConcern
  include ODSCodeConcern

  URN_HOME_EDUCATED = "999999"
  URN_UNKNOWN = "888888"

  audited
  has_associated_audits

  belongs_to :local_authority,
             foreign_key: :gias_local_authority_code,
             primary_key: :gias_code,
             optional: true

  has_many :location_year_groups,
           class_name: "Location::YearGroup",
           dependent: :destroy

  has_many :attendance_records
  has_many :gillick_assessments
  has_many :patient_locations
  has_many :pre_screenings
  has_many :team_locations

  has_many :consent_forms, through: :team_locations
  has_many :sessions, through: :team_locations
  has_many :teams, through: :team_locations
  has_many :organisations, through: :teams

  has_many :location_programme_year_groups,
           -> { includes(:location_year_group) },
           through: :location_year_groups

  # These integer values intentionally match the GIAS phases.
  enum :gias_phase,
       {
         not_applicable: 0,
         nursery: 1,
         primary: 2,
         middle_deemed_primary: 3,
         secondary: 4,
         middle_deemed_secondary: 5,
         sixteen_plus: 6,
         all_through: 7
       },
       prefix: true

  # This is based on the school statuses from the DfE GIAS data.
  enum :status,
       { unknown: 0, open: 1, closed: 2, closing: 3, opening: 4 },
       default: :unknown

  enum :type,
       {
         school: 0,
         generic_clinic: 1,
         community_clinic: 2,
         gp_practice: 3,
         generic_school: 4
       }

  scope :clinic, -> { generic_clinic.or(community_clinic) }

  scope :where_urn_and_site,
        ->(urn_and_site) do
          where(
            "CONCAT(locations.urn, locations.site) = ?",
            urn_and_site&.to_s&.strip
          )
        end

  scope :has_gias_year_groups,
        ->(values) { where("ARRAY[?]::integer[] <@ gias_year_groups", values) }

  scope :search_by_name,
        ->(query) do
          sanitized_name = "TRANSLATE(locations.name, '.''', '')"
          sanitized_query = "TRANSLATE(:query, '.''', '')"

          where("#{sanitized_query} <% #{sanitized_name}", query:).order(
            Arel.sql(
              "SIMILARITY(#{sanitized_name}, #{sanitized_query}) DESC",
              query:
            )
          )
        end

  scope :where_phase,
        ->(phase) { where(gias_phase: GIAS_PHASE_MAPPINGS.fetch(phase)) }

  scope :with_team,
        ->(academic_year:) do
          where(
            TeamLocation
              .where("team_locations.location_id = locations.id")
              .where(academic_year:)
              .arel
              .exists
          )
        end

  scope :without_team,
        ->(academic_year:) do
          where.not(
            TeamLocation
              .where("team_locations.location_id = locations.id")
              .where(academic_year:)
              .arel
              .exists
          )
        end

  scope :order_by_name, -> { order(:name) }

  normalizes :site, with: -> { it.presence&.strip }
  normalizes :urn, with: -> { it.presence&.strip }

  validates :name, presence: true
  validates :url, url: true, allow_nil: true

  with_options if: :community_clinic? do
    validates :gias_establishment_number, absence: true
    validates :gias_local_authority_code, absence: true
    validates :gias_phase, absence: true
    validates :ods_code, exclusion: { in: :organisation_ods_codes }
    validates :site, absence: true
    validates :urn, absence: true
  end

  with_options if: :generic_clinic? do
    validates :gias_establishment_number, absence: true
    validates :gias_local_authority_code, absence: true
    validates :gias_phase, absence: true
    validates :ods_code, absence: true
    validates :site, absence: true
    validates :urn, absence: true
  end

  with_options if: :generic_school? do
    validates :gias_establishment_number, absence: true
    validates :gias_local_authority_code, absence: true
    validates :gias_phase, inclusion: %w[not_applicable]
    validates :ods_code, absence: true
    validates :site, absence: true
    validates :urn, inclusion: [URN_HOME_EDUCATED, URN_UNKNOWN]
  end

  with_options if: :gp_practice? do
    validates :gias_establishment_number, absence: true
    validates :gias_local_authority_code, absence: true
    validates :gias_phase, absence: true
    validates :ods_code, presence: true
    validates :site, absence: true
    validates :urn, absence: true
  end

  with_options if: :school? do
    validates :gias_establishment_number, presence: true
    validates :gias_local_authority_code, presence: true
    validates :gias_phase, inclusion: Location.gias_phases.keys
    validates :ods_code, absence: true
    validates :site, uniqueness: { scope: :urn }, allow_nil: true
    validates :urn, presence: true, uniqueness: { unless: :site }
  end

  delegate :fhir_reference, to: :fhir_mapper

  def self.find_by_urn_and_site(urn_and_site)
    where_urn_and_site(urn_and_site).take
  end

  def self.find_by_urn_and_site!(urn_and_site)
    where_urn_and_site(urn_and_site).take!
  end

  def to_param
    # ODS code and URN+site are uniquely indexed.
    ods_code || urn_and_site || id
  end

  def urn_and_site
    return nil if urn.nil? && site.nil?
    site.nil? ? urn : urn + site
  end

  def year_groups
    @year_groups ||= location_year_groups.pluck_values
  end

  def programmes
    location_programme_year_groups.map(&:programme).sort.uniq
  end

  def clinic? = generic_clinic? || community_clinic?

  def dfe_number
    "#{gias_local_authority_code}#{gias_establishment_number}" if school?
  end

  def phase
    if gias_phase
      GIAS_PHASE_MAPPINGS
        .find { |_, values| values.include?(gias_phase) }
        &.first
    end
  end

  def as_json
    super.except("created_at", "systm_one_code", "updated_at").merge(
      "is_attached_to_team" =>
        team_locations.any? { it.academic_year == AcademicYear.pending }
    )
  end

  def teams_for_academic_year(academic_year)
    team_locations.where(academic_year:).includes(:team).map(&:team)
  end

  def attach_to_team!(team, academic_year:, subteam: nil)
    team_locations
      .find_or_initialize_by(team:, academic_year:)
      .tap { it.update!(subteam:) }
  end

  def import_year_groups!(values, academic_year:, source:)
    Location::YearGroup.import!(
      %i[location_id academic_year value source],
      values.map { |value| [id, academic_year, value, source] },
      on_duplicate_key_ignore: true
    )
  end

  def import_year_groups_from_gias!(academic_year:)
    import_year_groups!(gias_year_groups, academic_year:, source: "gias")
  end

  def import_default_programme_year_groups!(programmes, academic_year:)
    year_group_ids =
      location_year_groups.where(academic_year:).pluck(:value, :id).to_h

    rows =
      programmes.flat_map do |programme|
        programme.default_year_groups.filter_map do |year_group|
          if (year_group_id = year_group_ids[year_group])
            [year_group_id, programme.type]
          end
        end
      end

    Location::ProgrammeYearGroup.import!(
      %i[location_year_group_id programme_type],
      rows,
      on_duplicate_key_ignore: true
    )
  end

  private

  def organisation_ods_codes = Organisation.pluck(:ods_code)

  GIAS_PHASE_MAPPINGS = {
    "nursery" => %w[nursery],
    "primary" => %w[primary middle_deemed_primary],
    "secondary" => %w[secondary middle_deemed_secondary],
    "other" => %w[sixteen_plus all_through not_applicable]
  }.freeze

  def fhir_mapper
    @fhir_mapper ||= FHIRMapper::Location.new(self)
  end
end
