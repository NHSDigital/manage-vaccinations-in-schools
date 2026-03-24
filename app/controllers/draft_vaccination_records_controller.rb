# frozen_string_literal: true

class DraftVaccinationRecordsController < ApplicationController
  include Pagy::Backend
  include TodaysBatchConcern

  skip_after_action :verify_policy_scoped

  before_action :set_draft_vaccination_record
  before_action :set_patient
  before_action :set_session
  before_action :set_programme
  before_action :set_vaccination_record

  include WizardControllerConcern

  before_action :validate_params, only: :update
  before_action :set_batches,
                if: -> do
                  current_step == :batch &&
                    !@draft_vaccination_record.national_reporting_user_and_record?
                end
  before_action :set_vaccines,
                if: -> do
                  current_step == :batch &&
                    @draft_vaccination_record.national_reporting_user_and_record?
                end
  before_action :set_locations, if: -> { current_step == :location }
  before_action :set_supplied_by_users, if: -> { current_step == :supplier }
  before_action :set_back_link_path

  def show
    authorize @vaccination_record,
              @vaccination_record.new_record? ? :new? : :edit?

    render_wizard
  end

  def update
    authorize @vaccination_record,
              @vaccination_record.new_record? ? :create? : :update?

    @draft_vaccination_record.assign_attributes(update_params)

    case current_step
    when :date_and_time
      handle_date_and_time
    when :outcome
      handle_outcome
    when :location
      handle_location
    when :batch
      handle_batch
    when :dose_sequence
      handle_dose_sequence
    when :mmr_or_mmrv
      handle_mmr_or_mmrv
    when :confirm
      handle_confirm
    end

    if @draft_vaccination_record.editing? && current_step != :confirm
      jump_to("confirm")
    end

    reload_steps

    render_wizard @draft_vaccination_record
  end

  private

  def validate_params
    if current_step == :date_and_time
      TimeParamsNormalizer.call!(
        params: params[:draft_vaccination_record],
        field_name: :performed_at_time
      )

      date_validator =
        DateParamsValidator.new(
          field_name: :performed_at_date,
          object: @draft_vaccination_record,
          params: update_params
        )

      time_validator =
        TimeParamsValidator.new(
          field_name: :performed_at_time,
          object: @draft_vaccination_record,
          params: update_params
        )

      is_date_valid = date_validator.date_params_valid?
      is_time_valid = time_validator.time_params_valid?

      unless is_date_valid && is_time_valid
        render_wizard nil, status: :unprocessable_content
      end
    elsif current_step == :batch &&
          @draft_vaccination_record.national_reporting_user_and_record?
      validator =
        DateParamsValidator.new(
          field_name: :batch_expiry,
          object: @draft_vaccination_record,
          params: update_params
        )

      unless validator.date_params_valid?
        @draft_vaccination_record.errors.add(:batch_expiry, :invalid)
        set_vaccines
        render_wizard nil, status: :unprocessable_content
      end
    end
  end

  def handle_date_and_time
    if @draft_vaccination_record.performed_at.nil?
      @draft_vaccination_record.errors.add(:performed_at, :blank)
    end
  end

  def handle_outcome
    if !@draft_vaccination_record.administered? &&
         @draft_vaccination_record.location_id.present?
      # If not administered and location is set, we can skip to confirm.
      # Otherwise, we need to get the location information from the user.
      jump_to("confirm")
    end
  end

  def handle_batch
    if params.dig(:draft_vaccination_record, :todays_batch).present? &&
         update_params[:batch_id].in?(
           params[:draft_vaccination_record][:todays_batch]
         )
      self.todays_batch = policy_scope(Batch).find(update_params[:batch_id])
    end
  end

  def handle_dose_sequence
    jump_to("confirm")
  end

  def handle_mmr_or_mmrv
    if @draft_vaccination_record.mmrv_vaccine.nil?
      @draft_vaccination_record.errors.add(:mmrv_vaccine, :blank)
    end
    @draft_vaccination_record.disease_types =
      Programme::Variant::DISEASE_TYPES[
        @draft_vaccination_record.mmrv_vaccine ? "mmrv" : "mmr"
      ]
  end

  def handle_location
    if @session&.generic_clinic? ||
         @draft_vaccination_record.national_reporting_user_and_record?
      location_id = update_params[:location_id]

      if location_id == "unknown"
        @draft_vaccination_record.location_id = nil
        @draft_vaccination_record.location_name = "Unknown"
      else
        @draft_vaccination_record.location_id = location_id
        @draft_vaccination_record.location_name = nil
      end
    end
  end

  def handle_confirm
    return unless @draft_vaccination_record.save

    is_new_record = @vaccination_record.new_record?

    performed_at_date_changed =
      @vaccination_record.performed_at&.to_date !=
        @draft_vaccination_record.performed_at.to_date

    @draft_vaccination_record.write_to!(@vaccination_record)

    should_notify_parents =
      @vaccination_record.confirmation_sent? &&
        (
          @vaccination_record.outcome_changed? ||
            @vaccination_record.batch_number_changed? ||
            @vaccination_record.batch_expiry_changed? ||
            performed_at_date_changed
        )
    if is_new_record
      @vaccination_record.notify_parents =
        VaccinationNotificationCriteria.call(
          vaccination_record: @vaccination_record
        )
    end

    @vaccination_record.save!

    NextDoseTriageFactory.call(vaccination_record: @vaccination_record)

    PatientTeamUpdater.call(patient: @patient)
    PatientStatusUpdater.call(patient: @patient)

    if should_notify_parents
      @vaccination_record.notifier.send_confirmation(sent_by: current_user)
    end

    # In case the user navigates back to try and edit the newly created
    # vaccination record.
    @draft_vaccination_record.update!(editing_id: @vaccination_record.id)

    flash[
      :success
    ] = "Vaccination outcome recorded for #{@programme.name_in_sentence}"
  end

  def finish_wizard_path
    if @session&.today?
      session_patient_programme_path(
        @session,
        @patient,
        @programme,
        return_to: "record"
      )
    else
      vaccination_record_path(@vaccination_record)
    end
  end

  def update_params
    permitted_attributes = {
      batch: %i[batch_id vaccine_id batch_number batch_expiry],
      confirm: @draft_vaccination_record.editing? ? [] : %i[notes],
      date_and_time: %i[performed_at_date performed_at_time],
      delivery: %i[delivery_site delivery_method],
      dose: %i[full_dose],
      dose_sequence: %i[dose_sequence],
      identity: %i[
        identity_check_confirmed_by_patient
        identity_check_confirmed_by_other_name
        identity_check_confirmed_by_other_relationship
      ],
      location: %i[location_id],
      mmr_or_mmrv: %i[mmrv_vaccine],
      notes: %i[notes],
      outcome: %i[outcome],
      supplier: %i[supplied_by_user_id],
      vaccinator: %i[performed_by_given_name performed_by_family_name]
    }.fetch(current_step)

    params
      .fetch(:draft_vaccination_record, {})
      .permit(permitted_attributes)
      .merge(wizard_step: current_step)
  end

  def set_draft_vaccination_record
    @draft_vaccination_record =
      DraftVaccinationRecord.new(request_session: session, current_user:)
  end

  def set_patient
    @patient = @draft_vaccination_record.patient
  end

  def set_session
    @session = @draft_vaccination_record.session
  end

  def set_programme
    @programme = @draft_vaccination_record.programme
  end

  def set_vaccination_record
    @vaccination_record =
      @draft_vaccination_record.vaccination_record ||
        VaccinationRecord.new(
          patient: @patient,
          session: @session,
          programme: @programme
        )
  end

  def set_steps
    self.steps = @draft_vaccination_record.wizard_steps
  end

  def set_vaccines
    @vaccines = @programme.vaccines.select(&:nivs_name)
  end

  def set_batches
    vaccines = vaccine_criteria.apply(@programme.vaccines)

    scope = policy_scope(Batch).includes(:vaccine)

    @batches =
      scope
        .where(
          number: @draft_vaccination_record.batch_number,
          expiry: @draft_vaccination_record.batch_expiry,
          vaccine: @draft_vaccination_record.vaccine
        )
        .or(scope.not_archived.not_expired.where(vaccine: vaccines))
        .order_by_number_and_expiration
  end

  def set_locations
    if @draft_vaccination_record.national_reporting_user_and_record?
      @location_query = params[:q]
      scope = Location.gias_school.where(status: "open")

      if @location_query.present?
        scope = scope.search_by_name(@location_query)
        @pagy, @locations = pagy(scope, limit: 10)
      else
        @locations = Location.none
      end
    else
      @locations = policy_scope(Location).community_clinic
    end
  end

  def set_supplied_by_users
    @supplied_by_users = current_team.users.show_in_suppliers
  end

  def set_back_link_path
    @back_link_path =
      if @draft_vaccination_record.editing?
        if current_step == :confirm
          vaccination_record_path(@vaccination_record)
        else
          wizard_path("confirm")
        end
      elsif first_step_of_flow?
        if @session
          session_patient_programme_path(@session, @patient, @programme)
        else
          patient_programme_path(@patient, @programme)
        end
      else
        previous_wizard_path
      end
  end

  def first_step_of_flow?
    current_step.to_s == @draft_vaccination_record.first_active_wizard_step ||
      current_step == @draft_vaccination_record.wizard_steps.first
  end

  def vaccine_criteria
    vaccine_method =
      Vaccine.delivery_method_to_vaccine_method(
        @draft_vaccination_record.delivery_method
      )

    without_gelatine =
      @patient.vaccine_criteria(
        programme: @programme,
        academic_year: @session.academic_year
      ).without_gelatine

    VaccineCriteria.new(
      programme: @programme,
      vaccine_methods: [vaccine_method].compact,
      without_gelatine:
    )
  end
end
