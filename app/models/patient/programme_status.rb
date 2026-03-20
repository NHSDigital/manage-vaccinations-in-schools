# frozen_string_literal: true

# == Schema Information
#
# Table name: patient_programme_statuses
#
#  id                      :bigint           not null, primary key
#  academic_year           :integer          not null
#  consent_status          :integer          default("no_response"), not null
#  consent_vaccine_methods :integer          default([]), not null, is an Array
#  date                    :date
#  disease_types           :enum             is an Array
#  dose_sequence           :integer
#  programme_type          :enum             not null
#  status                  :integer          default("not_eligible"), not null
#  vaccine_methods         :integer          is an Array
#  without_gelatine        :boolean
#  location_id             :bigint
#  patient_id              :bigint           not null
#
# Indexes
#
#  idx_on_academic_year_patient_id_3d5bf8d2c8                 (academic_year,patient_id)
#  idx_on_patient_id_academic_year_programme_type_75e0e0c471  (patient_id,academic_year,programme_type) UNIQUE
#  index_patient_programme_statuses_on_location_id            (location_id)
#  index_patient_programme_statuses_on_patient_id             (patient_id)
#  index_patient_programme_statuses_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (patient_id => patients.id) ON DELETE => cascade
#
class Patient::ProgrammeStatus < ApplicationRecord
  include BelongsToProgramme
  include HasVaccineMethods

  belongs_to :patient
  belongs_to :location, optional: true

  has_many :patient_locations,
           -> do
             includes(
               location: [
                 :location_programme_year_groups,
                 {
                   team_locations: {
                     sessions: :session_programme_year_groups
                   }
                 }
               ]
             )
           end,
           through: :patient

  has_many :consents,
           -> do
             not_invalidated
               .response_provided
               .includes(:parent, :patient)
               .order(created_at: :desc)
           end,
           through: :patient

  has_many :triages,
           -> { not_invalidated.order(created_at: :desc) },
           through: :patient

  has_many :vaccination_records,
           -> { kept.order_by_performed_at },
           through: :patient

  has_one :attendance_record,
          -> { today },
          through: :patient,
          source: :attendance_records

  has_many :parents, through: :patient

  has_many :consent_notifications,
           -> { request.includes(session: :team_location) },
           through: :patient

  GROUPS = %w[
    not_eligible
    needs_consent
    has_refusal
    needs_triage
    due
    cannot_vaccinate
    vaccinated
  ].freeze

  NOT_ELIGIBLE_STATUSES = { "not_eligible" => 0 }.freeze

  NEEDS_CONSENT_STATUSES = {
    "needs_consent_request_not_scheduled" => 10,
    "needs_consent_request_scheduled" => 11,
    "needs_consent_request_failed" => 12,
    "needs_consent_no_response" => 13,
    "needs_consent_follow_up_requested" => 14,
    "needs_consent_no_contact_details" => 15
  }.freeze

  HAS_REFUSAL_STATUSES = {
    "has_refusal_consent_conflicts" => 20,
    "has_refusal_consent_refused" => 21
  }.freeze

  NEEDS_TRIAGE_STATUSES = { "needs_triage" => 30 }.freeze

  DUE_STATUSES = { "due" => 40 }.freeze

  CANNOT_VACCINATE_STATUSES = {
    "cannot_vaccinate_do_not_vaccinate" => 50,
    "cannot_vaccinate_delay_vaccination" => 51,
    "cannot_vaccinate_absent" => 52,
    "cannot_vaccinate_contraindicated" => 53,
    "cannot_vaccinate_refused" => 54,
    "cannot_vaccinate_unwell" => 55
  }.freeze

  VACCINATED_STATUSES = {
    "vaccinated_fully" => 60,
    "vaccinated_already" => 61
  }.freeze

  enum :status,
       {
         **NOT_ELIGIBLE_STATUSES,
         **NEEDS_CONSENT_STATUSES,
         **HAS_REFUSAL_STATUSES,
         **NEEDS_TRIAGE_STATUSES,
         **DUE_STATUSES,
         **CANNOT_VACCINATE_STATUSES,
         **VACCINATED_STATUSES
       },
       default: :not_eligible,
       validate: true

  enum :consent_status,
       {
         no_response: 0,
         given: 1,
         refused: 2,
         conflicts: 3,
         not_required: 4,
         follow_up_requested: 5,
         no_contact_details: 6,
         request_scheduled: 7,
         request_not_scheduled: 8
       },
       default: :no_response,
       prefix: :consent,
       validate: true

  array_enum consent_vaccine_methods: vaccine_methods

  validates :consent_vaccine_methods, subset: consent_vaccine_methods.keys

  scope :needs_consent, -> { where(status: NEEDS_CONSENT_STATUSES.keys) }

  scope :has_refusal, -> { where(status: HAS_REFUSAL_STATUSES.keys) }

  scope :cannot_vaccinate, -> { where(status: CANNOT_VACCINATE_STATUSES.keys) }

  scope :vaccinated, -> { where(status: VACCINATED_STATUSES.keys) }

  def needs_consent? = status.in?(NEEDS_CONSENT_STATUSES.keys)

  def has_refusal? = status.in?(HAS_REFUSAL_STATUSES.keys)

  def cannot_vaccinate? = status.in?(CANNOT_VACCINATE_STATUSES.keys)

  def needs_triage? = status.in?(NEEDS_TRIAGE_STATUSES.keys)

  def due? = status.in?(DUE_STATUSES.keys)

  def vaccinated? = status.in?(VACCINATED_STATUSES.keys)

  def group = GROUPS.find { status.starts_with?(it) }

  def assign
    self.consent_status = generator.consent_status
    self.consent_vaccine_methods = generator.consent_vaccine_methods
    self.date = generator.date
    self.disease_types = generator.disease_types
    self.dose_sequence = generator.dose_sequence
    self.location_id = generator.location_id
    self.status = generator.status
    self.vaccine_methods = generator.vaccine_methods
    self.without_gelatine = generator.without_gelatine
  end

  def vaccine_criteria = VaccineCriteria.from_programme_status(self)

  def needs_more_doses?
    dose_sequence.present? &&
      dose_sequence <= Programme.find(programme_type).maximum_dose_sequence
  end

  def on_last_dose?
    dose_sequence == Programme.find(programme_type).maximum_dose_sequence
  end

  def next_dose_eligible_date
    interval = Programme.find(programme_type).minimum_dose_interval
    return unless interval

    if cannot_vaccinate_delay_vaccination?
      date
    elsif date
      (date + interval).to_date
    end
  end

  private

  def generator
    @generator ||=
      StatusGenerator::Programme.new(
        programme_type:,
        academic_year:,
        patient:,
        patient_locations:,
        consents:,
        triages:,
        attendance_record:,
        vaccination_records:,
        parents:,
        consent_notifications:
      )
  end
end
