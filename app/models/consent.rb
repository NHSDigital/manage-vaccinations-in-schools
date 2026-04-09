# frozen_string_literal: true

# == Schema Information
#
# Table name: consents
#
#  id                                              :bigint           not null, primary key
#  academic_year                                   :integer          not null
#  disease_types                                   :enum             not null, is an Array
#  follow_up_outcome                               :integer
#  follow_up_requested                             :boolean
#  follow_up_resolved_at                           :datetime
#  health_answers                                  :jsonb            not null
#  invalidated_at                                  :datetime
#  notes                                           :text             default(""), not null
#  notify_parent_on_refusal                        :boolean
#  notify_parents_on_vaccination                   :boolean
#  parent_email                                    :string
#  parent_full_name                                :string
#  parent_phone                                    :string
#  parent_phone_receive_updates                    :boolean
#  parent_relationship_other_name                  :string
#  parent_relationship_type                        :string
#  patient_already_vaccinated_notification_sent_at :datetime
#  programme_type                                  :enum             not null
#  reason_for_refusal                              :integer
#  response                                        :integer          not null
#  route                                           :integer          not null
#  submitted_at                                    :datetime         not null
#  vaccine_methods                                 :integer          default([]), not null, is an Array
#  withdrawn_at                                    :datetime
#  without_gelatine                                :boolean
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  consent_form_id                                 :bigint
#  parent_id                                       :bigint
#  patient_id                                      :bigint           not null
#  recorded_by_user_id                             :bigint
#  team_id                                         :bigint           not null
#
# Indexes
#
#  index_consents_on_academic_year        (academic_year)
#  index_consents_on_consent_form_id      (consent_form_id)
#  index_consents_on_parent_id            (parent_id)
#  index_consents_on_patient_id           (patient_id)
#  index_consents_on_programme_type       (programme_type)
#  index_consents_on_recorded_by_user_id  (recorded_by_user_id)
#  index_consents_on_team_id              (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (consent_form_id => consent_forms.id)
#  fk_rails_...  (parent_id => parents.id)
#  fk_rails_...  (patient_id => patients.id)
#  fk_rails_...  (recorded_by_user_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#

class Consent < ApplicationRecord
  include BelongsToProgramme
  include GelatineVaccinesConcern
  include HasHealthAnswers
  include HasVaccineMethods
  include Invalidatable
  include Notable
  include Refusable

  audited associated_with: :patient

  belongs_to :patient
  belongs_to :team

  belongs_to :consent_form, optional: true
  belongs_to :parent, optional: true
  belongs_to :recorded_by,
             class_name: "User",
             optional: true,
             foreign_key: :recorded_by_user_id

  normalizes :parent_email, with: EmailAddressNormaliser.new
  normalizes :parent_phone, with: PhoneNumberNormaliser.new

  scope :for_session,
        ->(session) { where(programme_type: session.programme_types) }

  scope :withdrawn, -> { where.not(withdrawn_at: nil) }
  scope :not_withdrawn, -> { where(withdrawn_at: nil) }

  scope :response_provided, -> { not_response_not_provided }

  enum :response,
       { given: 0, refused: 1, not_provided: 2 },
       prefix: true,
       validate: true
  enum :route,
       { website: 0, phone: 1, paper: 2, in_person: 3, self_consent: 4 },
       prefix: "via",
       validate: true
  enum :follow_up_outcome,
       { confirmed: 0, withdrawn: 1 },
       prefix: :follow_up,
       validate: {
         allow_nil: true
       }

  validates :parent,
            presence: true,
            unless: -> do
              via_self_consent? || Flipper.enabled?(:patient_contacts)
            end
  validates :recorded_by,
            presence: true,
            unless: -> { via_self_consent? || via_website? }

  with_options if: :response_given? do
    validates :vaccine_methods, presence: true
    validates :without_gelatine, inclusion: [true, false]
  end

  def self.verbal_routes = routes.except("website", "self_consent")

  def name
    if via_self_consent?
      patient.full_name
    else
      parent_full_name.presence || parent.label
    end
  end

  delegate :vaccines, to: :programme

  def response_provided? = !response_not_provided?

  def withdrawn?
    withdrawn_at != nil
  end

  def not_withdrawn?
    withdrawn_at.nil?
  end

  def can_withdraw?
    not_withdrawn? && not_invalidated? && response_given?
  end

  def can_invalidate?
    not_invalidated?
  end

  def can_follow_up?
    not_invalidated? && refusal_with_follow_up?
  end

  def follow_up_resolved? = follow_up_resolved_at.present?

  def responded_at
    invalidated_at || withdrawn_at || submitted_at
  end

  def requires_reason_for_refusal? = super || withdrawn?

  def can_have_reason_for_refusal? = requires_reason_for_refusal?

  def requires_notes? = super || invalidated?

  def requires_triage?
    response_given? && health_answers_require_triage?
  end

  alias_method :should_invalidate_existing_triages?, :requires_triage?

  def should_invalidate_existing_patient_specific_directions?
    return true if should_invalidate_existing_triages?

    # TODO: Make this more generic. At the moment PSD is only used for nasal
    #  flu, but no reason it couldn't be applied to other programmes in the
    #  future.
    programme.flu? && !vaccine_method_nasal?
  end

  # Conditionally invalidate triages and PSDs when recording a new consent.
  # Only invalidates if the new consent has health answers requiring triage,
  # meaning it supersedes any existing triages.
  def invalidate_existing_triage_and_patient_specific_directions!
    if should_invalidate_existing_patient_specific_directions?
      invalidate_patient_specific_directions!
    end
    invalidate_triages! if should_invalidate_existing_triages?
  end

  # Unconditionally invalidate all triages and PSDs for this consent's
  # patient/programme/academic year. Used when withdrawing or invalidating
  # an existing consent.
  def invalidate_all_triages_and_patient_specific_directions!
    invalidate_triages!
    invalidate_patient_specific_directions!
  end

  def parent_relationship
    patient.parent_relationships.find { it.parent_id == parent_id }
  end

  def contacts
    return [] unless Flipper.enabled?(:patient_contacts)

    # TODO: Handle existing contacts as well as new ones

    [].tap do |contacts|
      if parent_email.present?
        contacts << patient.contacts.build(
          contact_method: :email,
          email: parent_email,
          full_name: parent_full_name,
          relationship: parent_relationship_type,
          relationship_other_name: parent_relationship_other_name,
          source: :consent_response
        )
      end
      if parent_phone.present?
        contacts << patient.contacts.build(
          contact_method: :phone,
          phone: parent_phone,
          phone_receive_updates: parent_phone_receive_updates,
          full_name: parent_full_name,
          relationship: parent_relationship_type,
          relationship_other_name: parent_relationship_other_name,
          source: :consent_response
        )
      end
    end
  end

  def matched_manually?
    !consent_form.nil? && !recorded_by_user_id.nil?
  end

  def self.from_consent_form!(consent_form, patient:, current_user:)
    raise ConsentFormNotRecorded unless consent_form.recorded?

    ActiveRecord::Base.transaction do
      parent =
        consent_form.find_or_create_parent_with_relationship_to!(patient:)

      patient.assign_ethnicity_from!(consent_form)

      consents =
        consent_form.consent_form_programmes.map do |consent_form_programme|
          patient.consents.create!(
            academic_year: consent_form.academic_year,
            consent_form:,
            disease_types: consent_form_programme.disease_types,
            follow_up_requested: consent_form_programme.follow_up_requested,
            health_answers: consent_form.health_answers,
            notes: consent_form_programme.notes,
            parent:,
            parent_full_name: consent_form.parent_full_name,
            parent_email: consent_form.parent_email,
            parent_phone: consent_form.parent_phone,
            parent_phone_receive_updates:
              consent_form.parent_phone_receive_updates,
            parent_relationship_type: consent_form.parent_relationship_type,
            parent_relationship_other_name:
              consent_form.parent_relationship_other_name,
            programme_type: consent_form_programme.programme_type,
            reason_for_refusal: consent_form_programme.reason_for_refusal,
            recorded_by: current_user,
            response: consent_form_programme.response,
            route: "website",
            submitted_at: consent_form.recorded_at,
            team: consent_form.team,
            vaccine_methods: consent_form_programme.vaccine_methods,
            without_gelatine: consent_form_programme.without_gelatine
          )
        end

      PatientStatusUpdater.call(patient:)

      consents
    end
  end

  def update_vaccination_records_no_notify!
    vaccination_records =
      VaccinationRecord.for_programme(programme).where(patient:)

    vaccination_records.find_each do |vaccination_record|
      vaccination_record.update!(
        notify_parents:
          VaccinationNotificationCriteria.call(vaccination_record:)
      )
    end
  end

  def resolve_follow_up!(outcome:, notes: nil, invalidate: false)
    ActiveRecord::Base.transaction do
      attrs = {
        follow_up_requested: false,
        follow_up_outcome: outcome,
        follow_up_resolved_at: Time.current
      }

      attrs[:invalidated_at] = Time.current if invalidate
      attrs[:notes] = notes if notes.present?

      update!(attrs)

      PatientStatusUpdater.call(patient: patient)
    end
  end

  def notifier = Notifier::Consent.new(self)

  class ConsentFormNotRecorded < StandardError
  end

  private

  def invalidate_triages!
    patient.triages.where(academic_year:, programme_type:).invalidate_all
  end

  def invalidate_patient_specific_directions!
    patient
      .patient_specific_directions
      .where(academic_year:, programme_type:)
      .invalidate_all
  end
end
