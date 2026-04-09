# frozen_string_literal: true

class DraftConsent
  include RequestSessionPersistable
  include EditableWrapper
  include WizardStepConcern

  include ActiveRecord::AttributeMethods::Serialization
  include GelatineVaccinesConcern
  include HasHealthAnswers
  include Programmable

  attr_reader :new_or_existing_contact
  attr_accessor :triage_form_valid

  attribute :academic_year, :integer
  attribute :contact_ids, array: true, default: []
  attribute :disease_types, array: true, default: []
  attribute :health_answers, array: true, default: []
  attribute :injection_alternative, :boolean
  attribute :notes, :string
  attribute :notify_parent_on_refusal, :boolean
  attribute :notify_parents_on_vaccination, :boolean
  attribute :parent_email, :string
  attribute :parent_full_name, :string
  attribute :parent_id, :integer
  attribute :parent_phone, :string
  attribute :parent_phone_receive_updates, :boolean
  attribute :parent_relationship_other_name, :string
  attribute :parent_relationship_type, :string
  attribute :parent_responsibility, :boolean
  attribute :patient_id, :integer
  attribute :programme_type, :string
  attribute :reason_for_refusal, :string
  attribute :recorded_by_user_id, :integer
  attribute :response, :string
  attribute :route, :string
  attribute :session_id, :integer
  attribute :triage_add_patient_specific_direction, :boolean
  attribute :triage_delay_vaccination_until, :string
  attribute :triage_notes, :string
  attribute :triage_status_option, :string
  attribute :vaccine_methods, array: true, default: []
  attribute :follow_up_consent_id, :integer
  attribute :follow_up_flow, :boolean, default: false
  attribute :vaccine_stock_is_available, :boolean
  attribute :without_gelatine, :boolean

  def initialize(current_user:, **attributes)
    @current_user = current_user
    super(**attributes)
  end

  FLU_RESPONSES = %w[given_nasal given_injection].freeze

  def wizard_steps
    [
      (:who unless follow_up_flow?),
      (:parent_details unless via_self_consent?),
      (:route unless via_self_consent?),
      (:mmrv_vaccine_availability if eligible_for_mmrv?),
      :agree,
      (:notify_parents_on_vaccination if response_given? && via_self_consent?),
      (:questions if response_given?),
      (:triage if triage_allowed? && requires_triage?),
      (:reason_for_refusal if response_refused?),
      (:notify_parent_on_refusal if ask_notify_parent_on_refusal?),
      (:notes if requires_notes?),
      :confirm
    ].compact
  end

  on_wizard_step :who, exact: true do
    validates :new_or_existing_contact, presence: true
  end

  on_wizard_step :parent_details, exact: true do
    validates :parent_phone_receive_updates, inclusion: { in: [true, false] }
  end

  validates :parent_email,
            notify_safe_email: {
              allow_blank: true
            },
            presence: {
              if: -> do
                required_for_step?(:parent_details, exact: true) &&
                  parent_phone.blank?
              end
            }
  validates :parent_phone,
            phone: {
              allow_blank: true
            },
            presence: {
              if: -> do
                required_for_step?(:parent_details, exact: true) &&
                  (parent_email.blank? || parent_phone_receive_updates)
              end
            }

  with_options if: -> { required_for_step?(:parent_details, exact: true) } do
    validates :parent_full_name, presence: true
    validates :parent_relationship_type,
              inclusion: {
                in: ParentRelationship.types.keys - %w[unknown]
              }
  end

  with_options if: -> do
                 parent_relationship_type == "other" &&
                   required_for_step?(:parent_details, exact: true)
               end do
    validates :parent_relationship_other_name,
              presence: true,
              length: {
                maximum: 300
              }
    validates :parent_responsibility, inclusion: [true]
  end

  on_wizard_step :route, exact: true do
    validates :route, inclusion: { in: Consent.routes.keys }
  end

  on_wizard_step :vaccine_availability, exact: true do
    validates :vaccine_stock_is_available, inclusion: { in: [true, false] }
  end

  on_wizard_step :agree, exact: true do
    validates :response,
              inclusion: {
                in: Consent.responses.keys + FLU_RESPONSES
              }
    validates :injection_alternative,
              inclusion: {
                in: [true, false]
              },
              if: -> { response == "given_nasal" }
    validates :without_gelatine,
              inclusion: {
                in: [true, false]
              },
              if: -> { programme.mmr? && response == "given" }
  end

  on_wizard_step :notify_parents_on_vaccination, exact: true do
    validates :notify_parents_on_vaccination, inclusion: { in: [true, false] }
  end

  on_wizard_step :reason_for_refusal, exact: true do
    validates :reason_for_refusal,
              inclusion: {
                in: Consent.reason_for_refusals.keys
              }
  end

  on_wizard_step :notify_parent_on_refusal, exact: true do
    validates :notify_parent_on_refusal, inclusion: { in: [true, false] }
  end

  on_wizard_step :questions, exact: true do
    validate :health_answers_are_valid
  end

  on_wizard_step :triage, exact: true do
    validates :triage_form_valid, presence: true
  end

  on_wizard_step :notes, exact: true do
    validates :notes, presence: true, length: { maximum: 1000 }
  end

  on_wizard_step :confirm, exact: true do
    validates :outcome, presence: true
  end

  def new_or_existing_contact=(value)
    @new_or_existing_contact = value

    if value == "new"
      self.route = nil
      self.parent = nil
      self.contacts = []
    elsif value == "patient"
      self.route = "self_consent"
      self.parent = nil
      self.contacts = []
    else
      self.route = nil
      if Flipper.enabled?(:patient_contacts)
        self.contacts = patient.contacts.where(id: value.split(" ").map(&:to_i))
      else
        self.parent =
          patient.parents.find_by(id: value) ||
            Parent.where(
              consents: patient.consents.for_programme(programme)
            ).find_by(id: value)
      end
    end
  end

  def consent
    ConsentPolicy::Scope
      .new(@current_user, Consent)
      .resolve
      .find_by(id: editing_id)
  end

  def consent=(value)
    self.editing_id = value.id
  end

  def update_vaccine_methods_and_without_gelatine
    if flu_response?
      if response == "given_nasal"
        self.vaccine_methods = ["nasal"]
        self.without_gelatine = false
        vaccine_methods << "injection" if injection_alternative
      elsif response == "given_injection"
        self.vaccine_methods = ["injection"]
        self.without_gelatine = true
        self.injection_alternative = nil
      end
    elsif response_given?
      self.vaccine_methods = ["injection"]
      self.without_gelatine ||= false
      self.injection_alternative = nil
    else
      self.vaccine_methods = []
      self.without_gelatine = nil
      self.injection_alternative = nil
    end
  end

  def update_disease_types
    return if programme_type.nil?

    self.disease_types =
      if eligible_for_mmrv? && vaccine_stock_is_available
        Programme::Variant::DISEASE_TYPES["mmrv"]
      elsif is_mmr?
        Programme::Variant::DISEASE_TYPES["mmr"]
      else
        Programme::DISEASE_TYPES[programme_type]
      end
  end

  def parent
    return nil if via_self_consent?

    return nil if Flipper.enabled?(:patient_contacts)

    parent = Parent.find_by(id: parent_id) || Parent.new

    parent.email = parent_email
    parent.full_name = parent_full_name
    parent.phone = parent_phone
    parent.phone_receive_updates = parent_phone_receive_updates

    # We can't use find_or_initialize_by here because we need the object to
    # remain attached to the parent so we can save the parent with its
    # relationships.

    parent_relationship =
      parent.parent_relationships.find { it.patient_id == patient_id } ||
        parent.parent_relationships.build(patient_id:)

    parent_relationship.assign_attributes(
      patient:, # acts as preload
      type: parent_relationship_type,
      other_name: parent_relationship_other_name
    )

    if parent_relationship.new_record?
      parent.parent_relationships << parent_relationship
    end

    parent
  end

  def contacts
    return nil unless Flipper.enabled?(:patient_contacts)

    contacts = []

    if parent_email.present?
      contact =
        Contact.find_by(id: contact_ids, contact_method: :email) ||
          Contact.new(contact_method: :email)
      contact.email = parent_email
      contact.full_name = parent_full_name
      contact.relationship = parent_relationship_type
      contact.relationship_other_name = parent_relationship_other_name
      contact.patient = patient # acts as preload
      contacts << contact
    end

    if parent_phone.present?
      contact =
        Contact.find_by(id: contact_ids, contact_method: :phone) ||
          Contact.new(contact_method: :phone)
      contact.phone = parent_phone
      contact.phone_receive_updates = parent_phone_receive_updates
      contact.full_name = parent_full_name
      contact.relationship = parent_relationship_type
      contact.relationship_other_name = parent_relationship_other_name
      contact.patient = patient # acts as preload
      contacts << contact
    end

    contacts
  end

  def parent=(value)
    return if Flipper.enabled?(:patient_contacts)

    self.parent_id = value&.id

    parent_relationship = value&.parent_relationships&.find_by(patient_id:)

    self.parent_email = patient.restricted? ? "" : value&.email
    self.parent_full_name = value&.full_name
    self.parent_phone = patient.restricted? ? "" : value&.phone
    self.parent_phone_receive_updates = value&.phone_receive_updates
    self.parent_relationship_type = parent_relationship&.type
    self.parent_relationship_other_name = parent_relationship&.other_name
    self.parent_responsibility = value ? true : nil
  end

  def contacts=(value)
    return unless Flipper.enabled?(:patient_contacts)

    self.contact_ids = value.map(&:id)

    value.each do |contact|
      if contact.phone?
        self.parent_phone = patient.restricted? ? "" : contact.phone
        self.parent_phone_receive_updates = contact.phone_receive_updates
      end
      if contact.email?
        self.parent_email = patient.restricted? ? "" : contact.email
      end
      self.parent_full_name ||= contact.full_name
      self.parent_relationship_type = parent_relationship&.type
      self.parent_relationship_other_name = parent_relationship&.other_name
    end
  end

  def source_label
    if parent_relationship_type == "other"
      "Other – #{other_name}"
    else
      human_enum_name(:parent_relationship_type).capitalize
    end
  end

  def contact_label
    parent_full_name.presence || "Parent or guardian (name unknown)"
  end

  def label_with_contact
    if parent_relationship_type == "unknown"
      contact_label
    else
      "#{contact_label} (#{source_label.downcase_first})"
    end
  end

  def patient
    return nil if patient_id.nil?

    PatientPolicy::Scope.new(@current_user, Patient).resolve.find(patient_id)
  end

  def patient=(value)
    self.patient_id = value.id
  end

  def recorded_by
    return nil if recorded_by_user_id.nil?

    User.find(recorded_by_user_id)
  end

  def recorded_by=(value)
    self.recorded_by_user_id = value.id
  end

  def session
    return nil if session_id.nil?

    SessionPolicy::Scope.new(@current_user, Session).resolve.find(session_id)
  end

  def session=(value)
    self.session_id = value.id
    self.academic_year = value.academic_year
  end

  delegate :location, :team, to: :session, allow_nil: true

  def team_id = team&.id

  def write_to!(consent, triage_form:)
    self.response = "given" if flu_response?
    super(consent)

    consent.parent = parent
    consent.parent_full_name = parent_full_name
    consent.parent_email = parent_email
    consent.parent_phone = parent_phone
    consent.parent_phone_receive_updates = parent_phone_receive_updates
    consent.parent_relationship_type = parent_relationship_type
    consent.parent_relationship_other_name = parent_relationship_other_name
    consent.submitted_at ||= Time.current
    consent.academic_year = academic_year if academic_year.present?

    if triage_allowed? && requires_triage?
      triage_form.add_patient_specific_direction =
        triage_add_patient_bespecific_direction
      triage_form.current_user = recorded_by
      triage_form.delay_vaccination_until = triage_delay_vaccination_until
      triage_form.notes = triage_notes || ""
      triage_form.status_option = triage_status_option
    end
  end

  def follow_up_flow? = follow_up_flow == true

  def via_self_consent? = route == "self_consent"

  def send_confirmation? = notify_parent_on_refusal != false

  def flu_response?
    FLU_RESPONSES.include?(response)
  end

  def response_given?
    response == "given" || FLU_RESPONSES.include?(response)
  end

  def response_refused? = response == "refused"

  def responded_at = Time.current

  def invalidated? = false

  def withdrawn? = false

  def consent_form = nil

  def parent_relationship
    parent
      &.parent_relationships
      &.find { it.patient_id == patient_id }
      &.tap do
        it.patient = patient # acts as preload
        it.type = parent_relationship_type
        it.other_name = parent_relationship_other_name
      end
  end

  def human_enum_name(attribute)
    Consent.human_enum_name(attribute, send(attribute))
  end

  def vaccine_method_injection? = vaccine_methods.include?("injection")

  def vaccine_method_nasal? = vaccine_methods.include?("nasal")

  def vaccine_method_nasal_only? = vaccine_methods == %w[nasal]

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
      VaccineCriteria.from_consentable(self).apply(programme.vaccines.active)

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

  private

  def is_mmr? = programme_type == "mmr"

  def eligible_for_mmrv? = is_mmr? && patient&.eligible_for_mmrv?

  def readable_attribute_names
    writable_attribute_names + %w[parent]
  end

  def writable_attribute_names
    %w[
      disease_types
      health_answers
      notes
      notify_parent_on_refusal
      notify_parents_on_vaccination
      patient_id
      programme_type
      reason_for_refusal
      recorded_by_user_id
      response
      route
      team_id
      vaccine_methods
      without_gelatine
    ]
  end

  def vaccines = programme.vaccines

  def ask_notify_parent_on_refusal?
    response_refused? && reason_for_refusal == "personal_choice" &&
      !via_self_consent?
  end

  def requires_notes?
    response_refused? &&
      reason_for_refusal.in?(Consent::REASON_FOR_REFUSAL_REQUIRES_NOTES)
  end

  def triage_allowed?
    TriagePolicy.new(@current_user, Triage).new?
  end

  def triage_status_options
    Triage.new(patient:, programme:).status_options
  end

  def requires_triage?
    response_given? && health_answers_require_triage?
  end

  def health_answers_are_valid
    return if health_answers.map(&:valid?).all?

    health_answers.each_with_index do |health_answer, index|
      next unless health_answer.ask_notes?

      health_answer.errors.messages.each do |field, messages|
        messages.each do |message|
          errors.add("question-#{index}-#{field}", message)
        end
      end
    end
  end

  def request_session_key = "consent"

  def reset_unused_attributes
    update_vaccine_methods_and_without_gelatine
    update_disease_types

    self.notes = "" unless requires_notes?
    self.notify_parent_on_refusal = nil unless ask_notify_parent_on_refusal?
    self.reason_for_refusal = nil unless response_refused?

    if response_given?
      seed_health_questions if health_answers.empty?
    else
      self.health_answers = []
    end
  end
end
