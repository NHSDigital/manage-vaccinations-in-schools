# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id                              :bigint           not null, primary key
#  careplus_namespace              :string
#  careplus_password               :string
#  careplus_staff_code             :string
#  careplus_staff_type             :string
#  careplus_username               :string
#  careplus_venue_code             :string
#  days_before_consent_reminders   :integer          default(7), not null
#  days_before_consent_requests    :integer          default(21), not null
#  email                           :string
#  name                            :text             not null
#  national_reporting_cut_off_date :date
#  phone                           :string
#  phone_instructions              :string
#  privacy_notice_url              :string
#  privacy_policy_url              :string
#  programme_types                 :enum             not null, is an Array
#  type                            :integer          not null
#  workgroup                       :string           not null
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  organisation_id                 :bigint           not null
#  reply_to_id                     :uuid
#
# Indexes
#
#  index_teams_on_name             (name) UNIQUE
#  index_teams_on_organisation_id  (organisation_id)
#  index_teams_on_programme_types  (programme_types) USING gin
#  index_teams_on_workgroup        (workgroup) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organisation_id => organisations.id)
#
class Team < ApplicationRecord
  include DaysBeforeToWeeksBefore
  include FlipperActor
  include HasManyProgrammes
  include HasManyTeamLocations

  NATIONAL_REPORTING_YEAR_GROUPS = (-2..13).to_a.freeze

  # The number of days after the national reporting cut-off date when users will lose access to NIVS
  NIVS_SWITCH_OFF_DELAY_DAYS = 2

  audited associated_with: :organisation
  has_associated_audits

  self.inheritance_column = nil

  belongs_to :organisation

  has_many :archive_reasons
  has_many :batches
  has_many :clinic_notifications
  has_many :cohort_imports
  has_many :consents
  has_many :important_notices
  has_many :patient_specific_directions
  has_many :patient_teams
  has_many :subteams

  has_many :consent_forms, through: :team_locations
  has_many :sessions, through: :team_locations

  has_many :patients, through: :patient_teams
  has_many :vaccination_records, through: :sessions

  has_many :location_year_groups, through: :locations
  has_many :location_programme_year_groups,
           -> { includes(:location_year_group) },
           through: :location_year_groups

  has_and_belongs_to_many :users

  normalizes :email, with: EmailAddressNormaliser.new
  normalizes :phone, with: PhoneNumberNormaliser.new

  encrypts :careplus_username, :careplus_password

  enum :type,
       { point_of_care: 0, national_reporting: 1, support: 2 },
       validate: true,
       prefix: "has",
       suffix: "access"

  validates :name, presence: true, uniqueness: true
  with_options if: :has_point_of_care_access? do
    validates :email, notify_safe_email: true
    validates :phone, presence: true, phone: true
    validates :privacy_notice_url, presence: true
    validates :privacy_policy_url, presence: true
    validates :national_reporting_cut_off_date, absence: true
  end
  with_options if: :has_national_reporting_access? do
    validates :email, absence: true
    validates :phone, absence: true
    validates :privacy_notice_url, absence: true
    validates :privacy_policy_url, absence: true
  end
  with_options if: :has_support_access? do
    validates :email, absence: true
    validates :phone, absence: true
    validates :privacy_notice_url, absence: true
    validates :privacy_policy_url, absence: true
    validates :national_reporting_cut_off_date, absence: true
  end
  validates :workgroup, presence: true, uniqueness: true

  def to_param = workgroup

  def generic_clinic
    @generic_clinic ||= generic_clinics.preload(:team_locations).sole
  end

  def home_educated_school
    @home_educated_school ||=
      generic_schools
        .includes(:team_locations)
        .where(urn: Location::URN_HOME_EDUCATED)
        .sole
  end

  def unknown_school
    @unknown_school ||=
      generic_schools
        .includes(:team_locations)
        .where(urn: Location::URN_UNKNOWN)
        .sole
  end

  def year_groups(academic_year: nil)
    return NATIONAL_REPORTING_YEAR_GROUPS if has_national_reporting_access?

    academic_year ||= AcademicYear.pending
    location_programme_year_groups
      .joins(:location_year_group)
      .where(location_year_group: { academic_year: })
      .pluck_year_groups
  end

  def is_sais_team?
    has_point_of_care_access? || has_national_reporting_access?
  end

  def careplus_enabled?
    careplus_staff_code.present? && careplus_staff_type.present? &&
      careplus_venue_code.present?
  end
end
