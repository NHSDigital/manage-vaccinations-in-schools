# frozen_string_literal: true

class PatientSessions::ConsentsController < PatientSessions::BaseController
  before_action :set_consent, except: %i[create send_request]
  before_action :ensure_can_withdraw, only: %i[edit_withdraw update_withdraw]
  before_action :ensure_can_invalidate,
                only: %i[edit_invalidate update_invalidate]

  def create
    authorize Consent

    @draft_consent = DraftConsent.new(request_session: session, current_user:)

    @draft_consent.clear_attributes
    @draft_consent.assign_attributes(create_params)

    if @draft_consent.save
      redirect_to draft_consent_path(Wicked::FIRST_STEP)
    else
      render "patient_sessions/programmes/show",
             layout: "full",
             status: :unprocessable_content
    end
  end

  def send_request
    # For programmes that are administered together we should send the consent request together.
    programmes =
      ProgrammeGrouper
        .call(@session.programmes)
        .values
        .find { it.include?(@programme) }

    if @patient.notifier.can_send_consent_request?(
         programmes,
         academic_year: @academic_year
       )
      @patient.notifier.send_consent_request(
        programmes,
        session: @session,
        sent_by: current_user
      )
    end

    redirect_to session_patient_programme_path(@session, @patient, @programme),
                flash: {
                  success: "Consent request sent."
                }
  end

  def show
  end

  def edit_withdraw
    render :withdraw
  end

  def update_withdraw
    @consent.assign_attributes(withdraw_params)

    if @consent.valid?
      ActiveRecord::Base.transaction do
        @consent.save!

        update_patient_status
      end

      redirect_to session_patient_programme_consent_path
    else
      render :withdraw, status: :unprocessable_content
    end
  end

  def edit_invalidate
    render :invalidate
  end

  def update_invalidate
    @consent.assign_attributes(invalidate_params)

    if @consent.valid?
      ActiveRecord::Base.transaction do
        @consent.save!

        @consent.update_vaccination_records_no_notify!

        update_patient_status
      end

      redirect_to session_patient_programme_consent_path,
                  flash: {
                    success:
                      "Consent response from #{@consent.name} marked as invalid"
                  }
    else
      render :invalidate, status: :unprocessable_content
    end
  end

  private

  def set_consent
    @consent =
      @patient
        .consents
        .where(academic_year: @session.academic_year)
        .includes(:consent_form, :parent, patient: :parent_relationships)
        .find(params[:id])
  end

  def update_patient_status
    @consent.invalidate_all_triages_and_patient_specific_directions!

    PatientStatusUpdater.call(patient: @patient)
  end

  def ensure_can_withdraw
    redirect_to action: :show unless @consent.can_withdraw?
  end

  def ensure_can_invalidate
    redirect_to action: :show unless @consent.can_invalidate?
  end

  def create_params
    {
      patient: @patient,
      session: @session,
      programme: @programme,
      recorded_by: current_user
    }
  end

  def withdraw_params
    params.expect(consent: %i[reason_for_refusal notes]).merge(
      response: "refused",
      withdrawn_at: Time.current
    )
  end

  def invalidate_params
    params.expect(consent: :notes).merge(invalidated_at: Time.current)
  end

  def consent_request_needed?
    programme_status =
      @patient.programme_status(@programme, academic_year: @academic_year)

    programme_status.needs_consent_no_response? ||
      programme_status.needs_consent_request_scheduled? ||
      programme_status.needs_consent_request_not_scheduled?
  end
end
