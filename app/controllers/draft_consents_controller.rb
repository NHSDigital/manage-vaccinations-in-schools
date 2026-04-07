# frozen_string_literal: true

class DraftConsentsController < ApplicationController
  skip_after_action :verify_policy_scoped

  before_action :set_draft_consent
  before_action :set_patient
  before_action :set_session
  before_action :set_programme
  before_action :set_parent
  before_action :set_consent

  include WizardControllerConcern

  before_action :set_back_link_path
  before_action :set_new_or_existing_contact_options, if: :is_who_step?
  before_action :set_triage_form, if: :includes_triage_step?

  def show
    authorize Consent, :edit?

    render_wizard
  end

  def update
    authorize Consent

    case current_step
    when :agree
      handle_agree
    when :confirm
      handle_confirm
    when :questions
      handle_questions
    when :triage
      handle_triage
    when :mmrv_vaccine_availability
      handle_mmrv_vaccine_availability
    else
      @draft_consent.assign_attributes(update_params)
    end

    @draft_consent.seed_health_questions if current_step == :agree

    if @draft_consent.editing? && !@draft_consent.follow_up_flow? &&
         current_step != :confirm
      jump_to("confirm")
    end

    reload_steps

    render_wizard @draft_consent
  end

  private

  def handle_agree
    @draft_consent.assign_attributes(update_params)
    @draft_consent.update_vaccine_methods_and_without_gelatine
  end

  def handle_confirm
    return unless @draft_consent.save

    @draft_consent.write_to!(@consent, triage_form: @triage_form)

    @triage = nil

    ActiveRecord::Base.transaction do
      @triage = @triage_form&.save! if @draft_consent.response_given?

      if (parent = @consent.parent)
        parent.save! if parent.changed?
        parent.parent_relationships.select(&:changed?).each(&:save!)
      end

      @consent.save!

      unless includes_triage_step?
        @consent.invalidate_existing_triage_and_patient_specific_directions!
      end

      @consent.update_vaccination_records_no_notify!

      PatientStatusUpdater.call(patient: @patient)
    end

    if (old_consent_id = @draft_consent.follow_up_consent_id)
      Consent.find(old_consent_id).resolve_follow_up!(
        outcome: :withdrawn,
        notes:
          "#{@draft_consent.human_enum_name(:response)} in follow-up discussion.",
        invalidate: true
      )
    end

    if @draft_consent.send_confirmation?
      @consent.notifier.send_confirmation(
        session: @session,
        triage: @triage,
        sent_by: current_user
      )
    end

    heading_link_href =
      session_patient_programme_path(@session, @patient, @programme)

    flash[:success] = {
      heading: "Consent recorded for",
      heading_link_text: @patient.full_name,
      heading_link_href:
    }
  end

  def handle_questions
    questions_attrs = update_params.except(:wizard_step)

    @draft_consent.health_answers.each_with_index do |health_answer, index|
      attributes = questions_attrs["question_#{index}"]
      health_answer.assign_attributes(attributes) if health_answer.ask_notes?
    end

    @draft_consent.assign_attributes(wizard_step: current_step)
  end

  def handle_triage
    @triage_form.assign_attributes(triage_form_params)

    @draft_consent.assign_attributes(
      triage_add_patient_specific_direction:
        @triage_form.add_patient_specific_direction,
      triage_delay_vaccination_until: @triage_form.delay_vaccination_until,
      triage_form_valid: @triage_form.valid?,
      triage_notes: @triage_form.notes,
      triage_status_option: @triage_form.status_option,
      wizard_step: :triage
    )
  end

  def handle_mmrv_vaccine_availability
    @draft_consent.assign_attributes(update_params)
    @draft_consent.update_disease_types
  end

  def finish_wizard_path
    session_patients_path(@session)
  end

  def update_params
    permitted_attributes = {
      agree: %i[response injection_alternative without_gelatine],
      mmrv_vaccine_availability: %i[vaccine_stock_is_available],
      notes: %i[notes],
      notify_parent_on_refusal: %i[notify_parent_on_refusal],
      notify_parents_on_vaccination: %i[notify_parents_on_vaccination],
      parent_details: %i[
        parent_email
        parent_full_name
        parent_phone
        parent_phone_receive_updates
        parent_relationship_other_name
        parent_relationship_type
        parent_responsibility
      ],
      questions: questions_params,
      reason_for_refusal: %i[reason_for_refusal],
      route: %i[route],
      who: %i[new_or_existing_contact]
    }.fetch(current_step)

    params
      .fetch(:draft_consent, {})
      .permit(permitted_attributes)
      .merge(wizard_step: current_step)
  end

  def triage_form_params
    params.expect(
      triage_form: %i[
        add_patient_specific_direction
        delay_vaccination_until
        notes
        status_option
      ]
    )
  end

  def set_draft_consent
    @draft_consent = DraftConsent.new(request_session: session, current_user:)
  end

  def set_patient
    @patient = @draft_consent.patient
  end

  def set_session
    @session = @draft_consent.session
  end

  def set_programme
    @programme = @draft_consent.programme
  end

  def set_parent
    @parent = @draft_consent.parent
  end

  def set_consent
    @consent = @draft_consent.consent || Consent.new
  end

  def set_steps
    self.steps = @draft_consent.wizard_steps
  end

  def set_back_link_path
    @back_link_path =
      if @draft_consent.editing?
        wizard_path("confirm")
      elsif current_step == @draft_consent.wizard_steps.first
        session_patient_programme_path(@session, @patient, @programme)
      else
        previous_wizard_path
      end
  end

  def is_who_step? = current_step == :who

  NewOrExistingContactOption = Struct.new(:value, :label, :hint)

  def set_new_or_existing_contact_options
    @new_or_existing_contact_options = []

    if @patient.can_self_consent_without_gillick_competent?
      @new_or_existing_contact_options << NewOrExistingContactOption.new(
        value: "patient",
        label: "Child"
      )
    elsif @patient.can_self_consent_after_gillick_assessment?(
          location: @session.location,
          programme_type: @programme.type
        )
      @new_or_existing_contact_options << NewOrExistingContactOption.new(
        value: "patient",
        label: "Child (Gillick competent)"
      )
    end

    parent_relationships =
      (
        @patient.parent_relationships.includes(:parent) +
          @patient
            .consents
            .where(programme_type: @programme.type)
            .filter_map(&:parent_relationship)
      ).compact.uniq.sort_by(&:label)

    @new_or_existing_contact_options +=
      parent_relationships.map do |parent_relationship|
        NewOrExistingContactOption.new(
          value: parent_relationship.parent.id,
          label: parent_relationship.label_with_parent,
          hint: parent_relationship.parent.contact_label
        )
      end

    @new_or_existing_contact_options << NewOrExistingContactOption.new(
      value: "new",
      label: "Add a new parental contact"
    )
  end

  def includes_triage_step?
    current_step.in?(%i[triage confirm]) && steps.include?("triage")
  end

  def set_triage_form
    @triage_form =
      if includes_triage_step?
        TriageForm.new(
          add_patient_specific_direction:
            @draft_consent.triage_add_patient_specific_direction,
          consent_vaccine_methods: @draft_consent.vaccine_methods,
          consent_without_gelatine: @draft_consent.without_gelatine,
          current_user:,
          notes: @draft_consent.triage_notes,
          patient: @patient,
          session: @session,
          programme: @programme,
          status_option: @draft_consent.triage_status_option
        )
      end
  end

  # Returns:
  # {
  #   question_0: %i[notes response],
  #   question_1: %i[notes response],
  #   question_2: %i[notes response],
  #   ...
  # }
  def questions_params
    n = @draft_consent.health_answers&.size || 0
    Array.new(n) { |index| ["question_#{index}", %i[notes response]] }.to_h
  end
end
