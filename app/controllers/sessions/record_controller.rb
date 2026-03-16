# frozen_string_literal: true

class Sessions::RecordController < Sessions::BaseController
  include PatientSearchFormConcern
  include TodaysBatchConcern

  before_action :set_patient_search_form

  before_action :set_programme, except: :show
  before_action :set_vaccine_method, except: :show
  before_action :set_batches, except: :show

  def show
    scope = @session.patients.includes_statuses.includes(notes: :created_by)

    if @session.requires_registration?
      scope =
        scope.has_registration_status(
          %w[attending completed],
          session: @session
        )
    end

    patients =
      filter_on_vaccine_method_or_patient_specific_direction(
        @form.apply(scope)
      ).consent_given_and_safe_to_vaccinate(
        programmes: @form.programmes,
        academic_year: @session.academic_year
      )

    @pagy, @patients = pagy_array(patients)

    render layout: "session"
  end

  def edit_batch
    id = todays_batch_id(programme: @programme, vaccine_method: @vaccine_method)
    @todays_batch = authorize @batches.find(id), :edit?

    render :batch
  end

  def update_batch
    @todays_batch =
      authorize @batches.find_by(id: params.dig(:batch, :id)), :update?

    if @todays_batch
      self.todays_batch = @todays_batch

      redirect_to session_record_path(@session),
                  flash: {
                    success:
                      "The default batch for this session has been updated"
                  }
    else
      @todays_batch = Batch.new
      @todays_batch.errors.add(:id, "Select a default batch for this session")

      render :batch, status: :unprocessable_content
    end
  end

  private

  def set_programme
    @programme =
      current_user.programmes.find { it.type == params[:programme_type] }
  end

  def set_vaccine_method
    @vaccine_method = params[:vaccine_method]
  end

  def set_batches
    vaccines =
      @session.vaccines.for_programme(@programme).where(method: @vaccine_method)

    @batches =
      policy_scope(Batch)
        .where(vaccine: vaccines)
        .not_archived
        .not_expired
        .order_by_number_and_expiration
  end

  def filter_on_vaccine_method_or_patient_specific_direction(scope)
    return scope if current_user.is_nurse? || current_user.is_prescriber?
    return scope.none unless current_user.is_healthcare_assistant?

    original_scope = scope

    programme = @session.programmes
    academic_year = @session.academic_year
    team = current_team

    if @session.psd_enabled? && @session.national_protocol_enabled?
      original_scope.with_patient_specific_direction(
        programme:,
        academic_year:,
        team:
      ).or(
        original_scope.has_vaccine_criteria(
          vaccine_methods: %w[injection],
          programme:,
          academic_year:
        )
      )
    elsif @session.pgd_supply_enabled? && @session.national_protocol_enabled?
      original_scope.has_vaccine_criteria(
        vaccine_methods: [
          %w[nasal],
          %w[nasal injection],
          %w[injection nasal],
          %w[injection]
        ],
        programme:,
        academic_year:
      )
    elsif @session.psd_enabled?
      original_scope.with_patient_specific_direction(
        programme:,
        academic_year:,
        team:
      )
    elsif @session.pgd_supply_enabled?
      original_scope.has_vaccine_criteria(
        vaccine_methods: [%w[nasal], %w[nasal injection]],
        programme:,
        academic_year:
      )
    else
      original_scope.none
    end
  end
end
