# frozen_string_literal: true

# == Schema Information
#
# Table name: vaccination_records
#
#  id                                      :bigint           not null, primary key
#  batch_expiry                            :date
#  batch_number                            :string
#  confirmation_sent_at                    :datetime
#  delivery_method                         :integer
#  delivery_site                           :integer
#  discarded_at                            :datetime
#  disease_types                           :enum             not null, is an Array
#  dose_sequence                           :integer
#  full_dose                               :boolean
#  local_patient_id_uri                    :string
#  location_name                           :string
#  nhs_immunisations_api_etag              :string
#  nhs_immunisations_api_identifier_system :string
#  nhs_immunisations_api_identifier_value  :string
#  nhs_immunisations_api_primary_source    :boolean
#  nhs_immunisations_api_sync_pending_at   :datetime
#  nhs_immunisations_api_synced_at         :datetime
#  notes                                   :text
#  notify_parents                          :boolean
#  outcome                                 :integer          not null
#  pending_changes                         :jsonb            not null
#  performed_at_date                       :date             not null
#  performed_at_time                       :time
#  performed_by_family_name                :string
#  performed_by_given_name                 :string
#  performed_ods_code                      :string
#  programme_type                          :enum             not null
#  protocol                                :integer
#  source                                  :integer          not null
#  uuid                                    :uuid             not null
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  duplicate_of_vaccination_record_id      :bigint
#  local_patient_id                        :string
#  location_id                             :bigint
#  next_dose_delay_triage_id               :bigint
#  nhs_immunisations_api_id                :string
#  patient_id                              :bigint           not null
#  performed_by_user_id                    :bigint
#  reported_by_id                          :bigint
#  session_id                              :bigint
#  supplied_by_user_id                     :bigint
#  vaccine_id                              :bigint
#
# Indexes
#
#  idx_on_duplicate_of_vaccination_record_id_5071adce87            (duplicate_of_vaccination_record_id)
#  idx_on_patient_id_programme_type_outcome_453b557b54             (patient_id,programme_type,outcome) WHERE (discarded_at IS NULL)
#  index_vaccination_records_on_discarded_at                       (discarded_at)
#  index_vaccination_records_on_location_id                        (location_id)
#  index_vaccination_records_on_next_dose_delay_triage_id          (next_dose_delay_triage_id)
#  index_vaccination_records_on_nhs_immunisations_api_id           (nhs_immunisations_api_id) UNIQUE
#  index_vaccination_records_on_patient_id                         (patient_id)
#  index_vaccination_records_on_patient_id_and_session_id          (patient_id,session_id)
#  index_vaccination_records_on_pending_changes_not_empty          (id) WHERE (pending_changes <> '{}'::jsonb)
#  index_vaccination_records_on_performed_by_user_id               (performed_by_user_id)
#  index_vaccination_records_on_performed_ods_code_and_patient_id  (performed_ods_code,patient_id) WHERE (session_id IS NULL)
#  index_vaccination_records_on_programme_type                     (programme_type)
#  index_vaccination_records_on_reported_by_id                     (reported_by_id)
#  index_vaccination_records_on_session_id                         (session_id)
#  index_vaccination_records_on_supplied_by_user_id                (supplied_by_user_id)
#  index_vaccination_records_on_uuid                               (uuid) UNIQUE
#  index_vaccination_records_on_vaccine_id                         (vaccine_id)
#
# Foreign Keys
#
#  fk_rails_...  (duplicate_of_vaccination_record_id => vaccination_records.id)
#  fk_rails_...  (next_dose_delay_triage_id => triages.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (performed_by_user_id => users.id)
#  fk_rails_...  (reported_by_id => users.id)
#  fk_rails_...  (session_id => sessions.id)
#  fk_rails_...  (supplied_by_user_id => users.id)
#  fk_rails_...  (vaccine_id => vaccines.id)
#
class VaccinationRecord < ApplicationRecord
  include BelongsToProgramme
  include Confirmable
  include Discard::Model
  include HasDoseVolume
  include NHSImmunisationsAPISync
  include Notable
  include PendingChangesConcern
  include PerformableAtDateAndTime
  include PerformableBy

  audited associated_with: :patient

  DELIVERY_SITE_SNOMED_CODES_AND_TERMS = {
    left_thigh: ["61396006", "Structure of left thigh"],
    right_thigh: ["11207009", "Structure of right thigh"],
    left_arm_upper_position: ["368208006", "Left upper arm structure"],
    left_arm_lower_position: ["368208006", "Left upper arm structure"],
    right_arm_upper_position: ["368209003", "Right upper arm structure"],
    right_arm_lower_position: ["368209003", "Right upper arm structure"],
    left_buttock: ["723979003", "Structure of left buttock"],
    right_buttock: ["723980000", "Structure of right buttock"],
    nose: ["279549004", "Nasal cavity structure"]
  }.with_indifferent_access

  DELIVERY_METHOD_SNOMED_CODES_AND_TERMS = {
    intramuscular: %w[78421000 Intramuscular],
    subcutaneous: %w[34206005 Subcutaneous],
    nasal_spray: %w[46713006 Nasal]
  }.with_indifferent_access

  belongs_to :vaccine, optional: true

  belongs_to :performed_by_user, class_name: "User", optional: true
  belongs_to :reported_by, class_name: "User", optional: true
  belongs_to :supplied_by,
             class_name: "User",
             foreign_key: :supplied_by_user_id,
             optional: true

  belongs_to :next_dose_delay_triage, class_name: "Triage", optional: true
  belongs_to :duplicate_of_vaccination_record,
             class_name: "VaccinationRecord",
             optional: true

  has_and_belongs_to_many :immunisation_imports

  belongs_to :location, optional: true
  belongs_to :patient
  belongs_to :session, optional: true

  has_one :identity_check, autosave: true, dependent: :destroy
  has_one :organisation, through: :session
  has_one :subteam, through: :session
  has_one :team, through: :session

  after_update :recalculate_next_dose_delay_triage_date,
               if: :saved_change_to_performed_at_date?

  scope :joins_organisation_on_performed_ods_code, -> { joins(<<-SQL) }
    INNER JOIN organisations organisation
    ON vaccination_records.performed_ods_code = organisation.ods_code
  SQL

  scope :joins_teams_on_performed_ods_code,
        -> { joins_organisation_on_performed_ods_code.joins(<<-SQL) }
    INNER JOIN teams ON organisation.id = teams.organisation_id
  SQL

  scope :for_academic_year,
        ->(academic_year) do
          where(performed_at_date: academic_year.to_academic_year_date_range)
        end

  scope :order_by_performed_at,
        -> do
          order("performed_at_date DESC, performed_at_time DESC NULLS LAST")
        end

  enum :protocol, { pgd: 0, psd: 1, national: 2 }, validate: { allow_nil: true }

  enum :delivery_method,
       { intramuscular: 0, subcutaneous: 1, nasal_spray: 2 },
       prefix: true

  enum :delivery_site,
       {
         left_arm_upper_position: 2,
         left_arm_lower_position: 3,
         right_arm_upper_position: 4,
         right_arm_lower_position: 5,
         left_thigh: 6,
         right_thigh: 7,
         left_buttock: 8,
         right_buttock: 9,
         nose: 10
       },
       prefix: true

  enum :outcome,
       {
         administered: 0,
         refused: 1,
         unwell: 2,
         contraindicated: 3,
         already_had: 4
       },
       validate: true

  enum :source,
       {
         service: 0,
         historical_upload: 1,
         nhs_immunisations_api: 2,
         consent_refusal: 3,
         national_reporting: 4,
         manual_report: 5
       },
       prefix: "sourced_from",
       validate: true

  validates :full_dose,
            inclusion: [true, false],
            if: -> { administered? && !sourced_from_nhs_immunisations_api? }

  validates :protocol,
            :vaccine_id,
            :batch_number,
            :batch_expiry,
            presence: true,
            if: -> { administered? && sourced_from_service? }

  validates :location_name,
            absence: {
              unless: :requires_location_name?
            },
            presence: {
              if: :requires_location_name?
            }

  validates :dose_sequence,
            comparison: {
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: :maximum_dose_sequence,
              allow_nil: true
            }

  validates :performed_at_date,
            comparison: {
              less_than_or_equal_to: -> { Date.current }
            }

  validates :nhs_immunisations_api_identifier_system,
            presence: {
              if: :sourced_from_nhs_immunisations_api?
            },
            absence: {
              unless: :sourced_from_nhs_immunisations_api?
            }

  validates :nhs_immunisations_api_identifier_value,
            presence: {
              if: :sourced_from_nhs_immunisations_api?
            },
            absence: {
              unless: :sourced_from_nhs_immunisations_api?
            }

  validates :nhs_immunisations_api_primary_source,
            inclusion: {
              in: [true, false],
              if: :nhs_immunisations_api_id
            },
            absence: {
              unless: :nhs_immunisations_api_id
            }

  validates :local_patient_id,
            :local_patient_id_uri,
            absence: {
              unless: :sourced_from_national_reporting?
            }

  after_save :generate_important_notice_if_needed

  delegate :fhir_record, to: :fhir_mapper

  class << self
    delegate :from_fhir_record, to: FHIRMapper::VaccinationRecord
  end

  delegate :academic_year, to: :performed_at_date

  def not_administered? = !administered?

  def reported_as_already_vaccinated?
    administered? && sourced_from_manual_report?
  end

  def show_in_academic_year?(current_academic_year)
    if programme.seasonal?
      academic_year == current_academic_year
    else
      academic_year <= current_academic_year
    end
  end

  def delivery_method_injection?
    delivery_method_intramuscular? || delivery_method_subcutaneous?
  end

  def delivery_method_snomed_code
    DELIVERY_METHOD_SNOMED_CODES_AND_TERMS.fetch(delivery_method).first
  end

  def delivery_method_snomed_term
    DELIVERY_METHOD_SNOMED_CODES_AND_TERMS.fetch(delivery_method).second
  end

  def snomed_procedure_code = vaccine&.snomed_procedure_code(dose_sequence:)

  def snomed_procedure_term = vaccine&.snomed_procedure_term(dose_sequence:)

  def notifier = Notifier::VaccinationRecord.new(self)

  private

  def requires_location_name? = location.nil?

  delegate :maximum_dose_sequence, to: :programme

  def fhir_mapper
    @fhir_mapper ||= FHIRMapper::VaccinationRecord.new(self)
  end

  def recalculate_next_dose_delay_triage_date
    return if next_dose_delay_triage.blank?
    return unless administered?

    previous_performed_at_date, current_performed_at_date =
      saved_change_to_performed_at_date

    days_difference =
      (current_performed_at_date - previous_performed_at_date).to_i

    new_delay_date =
      next_dose_delay_triage.delay_vaccination_until + days_difference.days

    next_dose_delay_triage.assign_attributes(
      delay_vaccination_until: new_delay_date,
      notes: "Next dose #{new_delay_date.to_fs(:long)}"
    )

    next_dose_delay_triage.save!

    PatientStatusUpdater.call(patient:)
  end

  def should_generate_important_notice?
    if id_previously_changed? # new_record? is not available in after_save
      !notify_parents # important notices are only generated if this is false
    else
      notify_parents_previously_changed?
    end
  end

  def generate_important_notice_if_needed
    if should_generate_important_notice?
      ImportantNoticeGeneratorJob.perform_later([patient_id])
    end
  end
end
