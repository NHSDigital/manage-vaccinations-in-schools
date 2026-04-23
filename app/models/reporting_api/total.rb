# frozen_string_literal: true

# == Schema Information
#
# Table name: reporting_api_totals
#
#  id                                    :text             primary key
#  academic_year                         :integer
#  consent_status                        :integer
#  has_already_vaccinated_consent        :boolean
#  is_archived                           :boolean
#  patient_gender                        :text
#  patient_local_authority_code          :string
#  patient_local_authority_official_name :string
#  patient_school_local_authority_code   :string
#  patient_school_name                   :text
#  patient_school_urn                    :string
#  patient_year_group                    :integer
#  programme_type                        :enum
#  status                                :integer
#  patient_id                            :bigint
#  session_location_id                   :bigint
#  team_id                               :bigint
#
# Indexes
#
#  ix_rapi_totals_id                     (id) UNIQUE
#  ix_rapi_totals_session_loc            (session_location_id)
#  ix_rapi_totals_team_year_prog_status  (team_id,academic_year,programme_type,status)
#  ix_rapi_totals_year_group             (patient_year_group)
#
class ReportingAPI::Total < ApplicationRecord
  self.primary_key = :id

  belongs_to :patient
  belongs_to :team

  VACCINATED_STATUSES = Patient::ProgrammeStatus::VACCINATED_STATUSES.values

  CONSENT_NO_RESPONSE = 0
  CONSENT_GIVEN = 1
  CONSENT_REFUSED = 2
  CONSENT_CONFLICTS = 3
  CONSENT_NOT_REQUIRED = 4
  NO_CONTACT_DETAILS = 6
  REQUEST_SCHEDULED = 7
  REQUEST_NOT_SCHEDULED = 8

  CONSENT_GIVEN_STATUSES = [CONSENT_GIVEN, CONSENT_NOT_REQUIRED].freeze

  NO_CONSENT_STATUSES = [
    CONSENT_NO_RESPONSE,
    CONSENT_REFUSED,
    CONSENT_CONFLICTS,
    NO_CONTACT_DETAILS,
    REQUEST_SCHEDULED,
    REQUEST_NOT_SCHEDULED
  ].freeze

  CONSENT_NO_RESPONSE_STATUSES = [
    CONSENT_NO_RESPONSE,
    NO_CONTACT_DETAILS,
    REQUEST_SCHEDULED,
    REQUEST_NOT_SCHEDULED
  ].freeze

  scope :not_archived, -> { where(is_archived: false) }
  scope :vaccinated,
        -> do
          where(status: VACCINATED_STATUSES).or(
            where(has_already_vaccinated_consent: true)
          )
        end

  attribute :cohort, :integer
  attribute :vaccinated, :integer
  attribute :not_vaccinated, :integer
  attribute :consent_given, :integer
  attribute :no_consent, :integer
  attribute :consent_no_response, :integer
  attribute :consent_refused, :integer
  attribute :consent_conflicts, :integer

  def readonly? = true

  def self.refresh!(concurrently: true)
    Scenic.database.refresh_materialized_view(
      table_name,
      concurrently:,
      cascade: false
    )
  end

  def self.cohort_count
    distinct.count(:patient_id)
  end

  def self.vaccinated_count
    vaccinated.distinct.count(:patient_id)
  end

  def self.consent_given_count
    where(consent_status: CONSENT_GIVEN_STATUSES).distinct.count(:patient_id)
  end

  def self.no_consent_count
    where(consent_status: NO_CONSENT_STATUSES).distinct.count(:patient_id)
  end

  def self.consent_no_response_count
    where(consent_status: CONSENT_NO_RESPONSE_STATUSES).distinct.count(
      :patient_id
    )
  end

  def self.consent_refused_count
    where(consent_status: CONSENT_REFUSED).distinct.count(:patient_id)
  end

  def self.consent_conflicts_count
    where(consent_status: CONSENT_CONFLICTS).distinct.count(:patient_id)
  end

  def self.with_aggregate_metrics
    vaccinated_condition =
      "status IN (#{VACCINATED_STATUSES.join(",")}) OR has_already_vaccinated_consent = true"
    consent_given_condition =
      "consent_status IN (#{CONSENT_GIVEN_STATUSES.join(",")})"
    no_consent_condition =
      "consent_status IN (#{NO_CONSENT_STATUSES.join(",")})"
    consent_no_response_condition =
      "consent_status IN (#{CONSENT_NO_RESPONSE_STATUSES.join(",")})"
    select(
      "COUNT(DISTINCT patient_id) AS cohort",
      "COUNT(DISTINCT patient_id) FILTER (WHERE #{vaccinated_condition}) AS vaccinated",
      "COUNT(DISTINCT patient_id) FILTER (WHERE NOT (#{vaccinated_condition})) AS not_vaccinated",
      "COUNT(DISTINCT patient_id) FILTER (WHERE #{consent_given_condition}) AS consent_given",
      "COUNT(DISTINCT patient_id) FILTER (WHERE #{no_consent_condition}) AS no_consent",
      "COUNT(DISTINCT patient_id) FILTER (WHERE #{consent_no_response_condition}) AS consent_no_response",
      "COUNT(DISTINCT patient_id) FILTER (WHERE consent_status = #{CONSENT_REFUSED}) AS consent_refused",
      "COUNT(DISTINCT patient_id) FILTER (WHERE consent_status = #{CONSENT_CONFLICTS}) AS consent_conflicts"
    )
  end
end
