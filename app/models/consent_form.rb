# frozen_string_literal: true

# == Schema Information
#
# Table name: consent_forms
#
#  id                                  :bigint           not null, primary key
#  address_line_1                      :string
#  address_line_2                      :string
#  address_postcode                    :string
#  address_town                        :string
#  archived_at                         :datetime
#  confirmation_sent_at                :datetime
#  date_of_birth                       :date
#  education_setting                   :integer
#  ethnic_background                   :integer
#  ethnic_background_other             :string
#  ethnic_group                        :integer
#  family_name                         :text
#  given_name                          :text
#  health_answers                      :jsonb            not null
#  nhs_number                          :string
#  notes                               :text             default(""), not null
#  parent_contact_method_other_details :string
#  parent_contact_method_type          :string
#  parent_email                        :string
#  parent_full_name                    :string
#  parent_phone                        :string
#  parent_phone_receive_updates        :boolean          default(FALSE), not null
#  parent_relationship_other_name      :string
#  parent_relationship_type            :string
#  preferred_family_name               :string
#  preferred_given_name                :string
#  recorded_at                         :datetime
#  school_confirmed                    :boolean
#  use_preferred_name                  :boolean
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  original_session_id                 :bigint
#  school_id                           :bigint
#  team_location_id                    :bigint           not null
#
# Indexes
#
#  index_consent_forms_on_nhs_number                  (nhs_number)
#  index_consent_forms_on_original_session_id         (original_session_id)
#  index_consent_forms_on_recorded                    (id) WHERE (recorded_at IS NOT NULL)
#  index_consent_forms_on_school_id                   (school_id)
#  index_consent_forms_on_team_location_id            (team_location_id)
#  index_consent_forms_on_unmatched_and_not_archived  (id) WHERE ((recorded_at IS NOT NULL) AND (archived_at IS NULL))
#
# Foreign Keys
#
#  fk_rails_...  (original_session_id => sessions.id)
#  fk_rails_...  (school_id => locations.id)
#  fk_rails_...  (team_location_id => team_locations.id)
#

class ConsentForm < ApplicationRecord
  include AddressConcern
  include AgeConcern
  include Archivable
  include BelongsToTeamLocation
  include Confirmable
  include EthnicityConcern
  include FullNameConcern
  include GelatineVaccinesConcern
  include HasHealthAnswers
  include Notable
  include WizardStepConcern

  before_save :reset_unused_attributes

  scope :recorded, -> { where.not(recorded_at: nil) }

  scope :unmatched, -> { recorded.not_archived.where.missing(:consents) }

  scope :has_any_programme_types_of,
        ->(programme_types) do
          where(
            ConsentFormProgramme
              .select("1")
              .where(
                "consent_form_programmes.consent_form_id = consent_forms.id"
              )
              .where(programme_type: programme_types)
              .arel
              .exists
          )
        end

  scope :for_session,
        ->(session) do
          where(
            team_location_id: session.team_location_id
          ).has_any_programme_types_of(session.programme_types)
        end

  attr_accessor :health_question_number,
                :parental_responsibility,
                :response,
                :chosen_programme,
                :injection_alternative,
                :without_gelatine,
                :vaccine_stock_is_available,
                :ethnicity_question

  belongs_to :original_session, class_name: "Session", optional: true
  belongs_to :school, class_name: "Location", optional: true

  has_many :consents
  has_many :notify_log_entries

  has_many :matched_patients,
           -> { distinct },
           through: :consents,
           source: :patient

  has_many :consent_form_programmes,
           -> { ordered },
           dependent: :destroy,
           autosave: true
  has_many :given_consent_form_programmes,
           -> { ordered.response_given },
           class_name: "ConsentFormProgramme"
  has_many :refused_consent_form_programmes,
           -> { ordered.response_refused },
           class_name: "ConsentFormProgramme"

  has_many :eligible_team_locations,
           -> { where(academic_year: it.team_location.academic_year) },
           through: :team,
           source: :team_locations

  has_many :eligible_schools,
           -> { school },
           through: :eligible_team_locations,
           source: :location

  enum :parent_contact_method_type,
       Parent.contact_method_types,
       prefix: :parent_contact_method,
       validate: {
         allow_nil: true
       }
  enum :parent_relationship_type,
       ParentRelationship.types,
       prefix: :parent_relationship,
       validate: {
         allow_nil: true
       }

  enum :education_setting, { school: 0, home: 1, none: 2 }, prefix: true

  encrypts :address_line_1,
           :address_line_2,
           :address_postcode,
           :address_town,
           :family_name,
           :given_name,
           :parent_contact_method_other_details,
           :parent_email,
           :parent_full_name,
           :parent_phone,
           :parent_relationship_other_name,
           :preferred_family_name,
           :preferred_given_name

  normalizes :given_name, with: -> { it.strip }
  normalizes :family_name, with: -> { it.strip }

  normalizes :parent_email, with: EmailAddressNormaliser.new
  normalizes :parent_phone, with: PhoneNumberNormaliser.new

  validates :address_line_1,
            :address_line_2,
            :address_town,
            :family_name,
            :given_name,
            :parent_contact_method_other_details,
            :parent_full_name,
            :parent_relationship_other_name,
            :preferred_family_name,
            :preferred_given_name,
            length: {
              maximum: 300
            }

  validates :parent_contact_method_other_details,
            presence: true,
            if: :parent_contact_method_other?

  validates :parent_phone,
            presence: {
              if: :parent_phone_receive_updates
            },
            phone: {
              allow_blank: true
            }

  validates :parent_relationship_other_name,
            presence: true,
            if: :parent_relationship_other?

  validates :ethnicity_question,
            inclusion: {
              in: %w[yes no]
            },
            on: :ethnicity_update,
            if: -> { wizard_step == :ethnicity }

  validates :ethnic_group,
            presence: true,
            on: :ethnicity_update,
            if: -> { wizard_step == :ethnic_group }

  validates :ethnic_background,
            presence: true,
            on: :ethnicity_update,
            if: -> { wizard_step == :ethnic_background }

  normalizes :nhs_number, with: -> { _1.presence&.gsub(/\s/, "") }

  on_wizard_step :name do
    validates :given_name, presence: true
    validates :family_name, presence: true
    validates :use_preferred_name, inclusion: { in: [true, false] }
    validates :preferred_given_name,
              presence: true,
              if: -> { use_preferred_name && preferred_family_name.blank? }
    validates :preferred_family_name,
              presence: true,
              if: -> { use_preferred_name && preferred_given_name.blank? }
  end

  on_wizard_step :date_of_birth do
    validates :date_of_birth,
              presence: true,
              comparison: {
                less_than: -> { Time.zone.today },
                greater_than_or_equal_to: -> { 22.years.ago.to_date },
                less_than_or_equal_to: -> { 3.years.ago.to_date }
              }
  end

  on_wizard_step :confirm_school do
    validates :school_confirmed, inclusion: { in: [true, false] }
  end

  on_wizard_step :education_setting do
    validates :education_setting, inclusion: { in: %w[school home none] }
  end

  on_wizard_step :school do
    validates :school_id,
              inclusion: {
                in: -> { it.eligible_schools.pluck(:id) }
              },
              unless: -> { education_setting_home? || education_setting_none? }
  end

  on_wizard_step :parent do
    validates :parent_full_name, presence: true
    validates :parent_email, notify_safe_email: true
    validates :parent_relationship_type, presence: true
  end

  validates :parental_responsibility,
            inclusion: {
              in: ["yes"]
            },
            if: ->(object) do
              object.parent_relationship_other? && object.wizard_step == :parent
            end

  on_wizard_step :contact_method do
    validates :parent_contact_method_type, presence: true
  end

  on_wizard_step :response_doubles, exact: true do
    validates :response, inclusion: %w[given given_one refused]
    validates :chosen_programme,
              presence: true,
              if: -> { response == "given_one" }
  end

  on_wizard_step :response_flu, exact: true do
    validates :response, inclusion: %w[given_injection given_nasal refused]
  end

  on_wizard_step :response_hpv, exact: true do
    validates :response, inclusion: %w[given refused]
  end

  on_wizard_step :response_mmr, exact: true do
    validates :response, inclusion: %w[given refused]
  end

  on_wizard_step :injection_alternative, exact: true do
    validates :injection_alternative, inclusion: %w[true false]
  end

  on_wizard_step :without_gelatine, exact: true do
    validates :without_gelatine, inclusion: %w[true false]
  end

  on_wizard_step :reason_for_refusal do
    validates :reason_for_refusal, presence: true
  end

  on_wizard_step :reason_for_refusal_notes do
    validates :reason_for_refusal_notes, presence: true
  end

  on_wizard_step :address do
    validates :address_line_1, presence: true
    validates :address_town, presence: true
    validates :address_postcode, postcode: true
  end

  on_wizard_step :health_question do
    validate :health_answers_valid?
  end

  ETHNICITY_STEPS = %i[ethnicity ethnic_group ethnic_background].freeze

  def ethnicity_steps = ETHNICITY_STEPS

  def wizard_steps
    refused_and_not_given = response_refused? && !response_given?
    refused_and_given = response_refused? && response_given?

    response_steps =
      ProgrammeGrouper
        .call(consent_form_programmes)
        .keys
        .map { :"response_#{it}" }

    [
      :name,
      :date_of_birth,
      (:confirm_school if location_is_school?),
      (:education_setting if location_is_clinic?),
      (:school if choose_school?),
      :parent,
      (:contact_method if parent_phone.present?)
    ].compact + response_steps +
      [
        (:without_gelatine if can_offer_without_gelatine?),
        (:reason_for_refusal if refused_and_not_given),
        (
          if refused_and_not_given && reason_for_refusal_requires_notes?
            :reason_for_refusal_notes
          end
        ),
        (:injection_alternative if can_offer_injection_as_alternative?),
        (:address if response_given?),
        (:health_question if response_given?),
        (:reason_for_refusal if refused_and_given),
        (
          if refused_and_given && reason_for_refusal_requires_notes?
            :reason_for_refusal_notes
          end
        )
      ].compact +
      (Flipper.enabled?(:ethnicity_capture) && recorded? ? ETHNICITY_STEPS : [])
  end

  def recorded? = recorded_at != nil

  def matched? = consents.exists?

  def response_given? = consent_form_programmes.any?(&:response_given?)

  def response_refused? = consent_form_programmes.any?(&:response_refused?)

  def human_enum_name(attribute)
    Consent.human_enum_name(attribute, send(attribute))
  end

  def each_health_answer
    return if health_answers.empty?
    return to_enum(:each_health_answer) unless block_given?

    health_answer = health_answers.first
    seen_health_answers = Set.new
    loop do
      if seen_health_answers.include?(health_answer.object_id)
        raise "Infinite loop detected"
      end
      seen_health_answers << health_answer.object_id

      yield health_answer
      next_health_answer_index = health_answer.next_health_answer_index
      break unless next_health_answer_index
      health_answer = health_answers[next_health_answer_index]
    end
  end

  def can_offer_injection_as_alternative?
    consent_form_programmes.select(&:response_given?).any?(
      &:vaccine_method_nasal?
    )
  end

  def can_offer_without_gelatine?
    response_given? &&
      consent_form_programmes.any? do
        it.programme.vaccine_may_contain_gelatine? &&
          !it.programme.has_multiple_vaccine_methods?
      end
  end

  def reason_for_refusal_requires_notes?
    consent_form_programmes.any?(&:reason_for_refusal_requires_notes?)
  end

  def matched_patient
    @matched_patient ||= (matched_patients.sole if matched?)
  end

  def session
    @session ||=
      if original_session_is_accurate?
        original_session
      else
        find_appropriate_session || original_session
      end
  end

  def session_dates_are_accurate?
    # There are some cases where the dates for the session are not considered
    # accurate enough to show to users.
    #
    # Specifically, if the parent indicated that their child goes to a
    # different school to the one we sent the consent form for, and we've been
    # unable to match the consent form to a child, we consider the session
    # and therefore the dates to not be accurate enough to display.

    original_session_is_accurate? || (session.present? && matched?)
  end

  def programmes = consent_form_programmes.map(&:programme)

  def programme_types = consent_form_programmes.map(&:programme_type)

  def vaccines
    @vaccines ||= Vaccine.where(programme_type: programme_types)
  end

  def find_or_create_parent_with_relationship_to!(patient:)
    parent =
      Parent.match_existing(
        patient:,
        email: parent_email,
        phone: parent_phone,
        full_name: parent_full_name
      ) || Parent.new

    parent.update!(
      contact_method_other_details: parent_contact_method_other_details,
      contact_method_type: parent_contact_method_type,
      email: parent_email,
      full_name: parent_full_name,
      phone: parent_phone,
      phone_receive_updates: parent_phone_receive_updates
    )

    patient
      .parent_relationships
      .find_or_initialize_by(parent:)
      .update!(
        type: parent_relationship_type,
        other_name: parent_relationship_other_name
      )

    parent
  end

  def summary_with_route
    if response_given? && response_refused?
      "Partial consent given (online)"
    elsif response_given?
      "Consent given (online)"
    elsif response_refused?
      "Consent refused (online)"
    end
  end

  def parent
    Parent.new(
      full_name: parent_full_name,
      email: parent_email,
      phone: parent_phone,
      phone_receive_updates: parent_phone_receive_updates,
      contact_method_type: parent_contact_method_type,
      contact_method_other_details: parent_contact_method_other_details
    )
  end

  def parent_relationship
    ParentRelationship.new(
      parent:,
      type: parent_relationship_type,
      other_name: parent_relationship_other_name
    )
  end

  def match_with_patient!(patient, current_user:)
    ActiveRecord::Base.transaction do
      notify_log_entries.update_all(patient_id: patient.id)

      school_changed = patient.school_id != school_for_school_move.id
      if school_changed && !patient.deceased? && !patient.invalidated?
        SchoolMove.find_or_initialize_by(patient:).update!(
          school: school_for_school_move,
          academic_year:,
          source: :parental_consent_form
        )
      end

      Consent.from_consent_form!(self, patient:, current_user:).each(
        &:invalidate_existing_triage_and_patient_specific_directions!
      )
    end
  end

  def matches_contact_details_for?(patient:)
    # We assume `true` if the patient has no parents, otherwise we would send
    # warnings to these parents about their contact details not matching.
    return true if patient.parents.empty?

    patient.parents.any? do |parent|
      (parent.email.present? && parent_email == parent.email) ||
        (parent.phone.present? && parent_phone == parent.phone)
    end
  end

  def home_educated
    return nil if education_setting_school?

    education_setting_home?
  end

  def home_educated_changed?
    education_setting_changed?
  end

  def school_for_school_move
    school || (home_educated ? team.home_educated_school : team.unknown_school)
  end

  def reason_for_refusal
    consent_form_programmes.find(&:response_refused?)&.reason_for_refusal
  end

  def reason_for_refusal=(value)
    consent_form_programmes
      .select(&:response_refused?)
      .each { it.reason_for_refusal = value }
  end

  def reason_for_refusal_notes
    consent_form_programmes.find(&:response_refused?)&.notes
  end

  def reason_for_refusal_notes=(value)
    consent_form_programmes
      .select(&:response_refused?)
      .each { it.notes = value }
  end

  def update_programme_responses
    case response
    when "given"
      consent_form_programmes.each do
        it.response = "given"
        it.vaccine_methods = %w[injection]
        it.without_gelatine = false
      end
    when "given_injection"
      consent_form_programmes.each do
        it.response = "given"
        it.vaccine_methods = %w[injection]
        it.without_gelatine = true # currently flu injection is to avoid gelatine
      end
    when "given_nasal"
      consent_form_programmes.each do
        it.response = "given"
        it.vaccine_methods = %w[nasal]
        it.without_gelatine = false
      end
    when "given_one"
      consent_form_programmes.each do |consent_form_programme|
        consent_form_programme.response =
          if consent_form_programme.programme.type == chosen_programme
            "given"
          else
            "refused"
          end
        consent_form_programme.vaccine_methods = %w[injection]
        consent_form_programme.without_gelatine = false
      end
    when "refused"
      consent_form_programmes.each { it.response = "refused" }
    end
  end

  def update_injection_alternative
    vaccine_methods =
      if ActiveModel::Type::Boolean.new.cast(injection_alternative)
        %w[nasal injection]
      else
        %w[nasal]
      end

    consent_form_programmes.each do |consent_form_programme|
      if consent_form_programme.vaccine_method_nasal?
        consent_form_programme.vaccine_methods = vaccine_methods
      end
    end
  end

  def update_without_gelatine
    consent_form_programmes.each do |consent_form_programme|
      consent_form_programme.without_gelatine = without_gelatine
    end
  end

  def seed_health_questions
    return unless response_given?

    # If the health answers change due to the chosen vaccines changing, we
    # want to try and keep as much as what the parents already wrote intact.
    # We do this be saving the answers to the question title (as the IDs
    # and ordering can change).

    existing_health_answers =
      health_answers.each_with_object({}) do |health_answer, memo|
        memo[health_answer.question] = {
          response: health_answer.response,
          notes: health_answer.notes
        }
      end

    vaccines =
      consent_form_programmes.select(&:response_given?).flat_map(&:vaccines)

    self.health_answers =
      HealthAnswersDeduplicator
        .call(vaccines:)
        .map do |health_answer|
          if (
               existing_health_answer =
                 existing_health_answers[health_answer.question]
             )
            health_answer.response = existing_health_answer[:response]
            health_answer.notes = existing_health_answer[:notes]
          end

          health_answer
        end
  end

  def notifier = Notifier::ConsentForm.new(self)

  private

  def original_session_is_accurate?
    # Some older consent forms don't have an original session.
    return false if original_session_id.nil?

    # Parent hasn't answered the question yet.
    return true if school_confirmed.nil?

    # Parent confirms the school is correct.
    school_confirmed || school_id == location_id
  end

  def find_appropriate_session
    # This tries to find the most appropriate session for this consent form.
    # It's used when generating links to patients in a session, or when
    # deciding which dates to show in an email. Under the hood, patients
    # belong to locations, not sessions.
    #
    # Although unlikely to happen in production, there can be a scenario
    # where multiple sessions at the same location offer the same programmes.
    # In this case, we have to make a guess about which is the most relevant
    # session.

    if location_is_clinic? || education_setting_home? || education_setting_none?
      return
    end

    session_location = school || location

    sessions_to_search =
      Session.joins(:team_location).where(
        team_location: {
          academic_year:,
          location: session_location,
          team:
        }
      )

    year_group =
      matched_patient&.year_group(academic_year:) ||
        date_of_birth&.academic_year&.to_year_group(academic_year:)

    sessions_to_search =
      if year_group
        sessions_to_search.where(
          "(?) >= ?",
          Session::ProgrammeYearGroup
            .select(
              "COUNT(DISTINCT session_programme_year_groups.programme_type)"
            )
            .where("sessions.id = session_programme_year_groups.session_id")
            .where(programme_type: programme_types, year_group:),
          programme_types.count
        )
      else
        sessions_to_search.has_all_programme_types_of(programme_types)
      end

    sessions_to_search.find(&:scheduled?) ||
      sessions_to_search.find(&:unscheduled?) || sessions_to_search.first
  end

  def via_self_consent? = false

  def health_answers_valid?
    if health_question_number.present?
      unless health_answers[health_question_number].valid?
        errors.add(:base, "Health answer(s) invalid")
        return false
      end
    else
      each_health_answer do |health_answer|
        unless health_answer.valid?
          errors.add(:base, "Health answer(s) invalid")
          return false
        end
      end
    end
    true
  end

  def location_is_school? = location.school?

  def location_is_clinic? = location.generic_clinic? || location.generic_school?

  def choose_school?
    location_is_clinic? ? education_setting_school? : !school_confirmed
  end

  def requires_notes? = archived?

  def reset_unused_attributes
    update_programme_responses

    unless use_preferred_name
      self.preferred_given_name = nil
      self.preferred_family_name = nil
    end

    if response_refused? && !response_given?
      self.address_line_1 = nil
      self.address_line_2 = nil
      self.address_town = nil
      self.address_postcode = nil

      self.health_answers = []
    end

    self.parent_contact_method_type = nil if parent_phone.blank?
    self.parent_contact_method_other_details =
      nil unless parent_contact_method_other?

    self.parent_relationship_other_name = nil unless parent_relationship_other?

    consent_form_programmes.each do
      if it.response_given?
        it.reason_for_refusal = nil
        it.notes = ""
      end
    end

    if school_confirmed
      self.education_setting = "school"
      self.school = location
    elsif education_setting_home? || education_setting_none?
      self.school = nil
      self.school_confirmed = false
    elsif school
      self.education_setting = "school"
    end
  end
end
