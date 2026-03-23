# frozen_string_literal: true

class PatientSessions::ConsentsController < PatientSessions::BaseController
  before_action :set_consent, except: %i[create send_request]
  before_action :set_consent_follow_up_form,
                only: %i[edit_follow_up update_follow_up]
  before_action :set_consent_confirm_refusal_form,
                only: %i[edit_confirm_refusal update_confirm_refusal]
  before_action :ensure_can_follow_up,
                only: %i[
                  edit_follow_up
                  update_follow_up
                  edit_confirm_refusal
                  update_confirm_refusal
                ]
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

  def edit_follow_up
    render :follow_up
  end

  def update_follow_up
    @form.assign_attributes(follow_up_params)

    if @form.valid?
      if @form.decision_stands?
        redirect_to confirm_refusal_session_patient_programme_consent_path
      else
        @draft_consent =
          DraftConsent.new(request_session: session, current_user:)
        @draft_consent.clear_attributes
        @draft_consent.assign_attributes(create_params)
        @draft_consent.follow_up_consent_id = @consent.id
        @draft_consent.follow_up_flow = true
        @draft_consent.new_or_existing_contact = @consent.parent_id.to_s
        @draft_consent.route = "phone"

        if @draft_consent.save
          redirect_to draft_consent_path("agree")
        else
          render :follow_up, status: :unprocessable_content
        end
      end
    else
      render :follow_up, status: :unprocessable_content
    end
  end

  def edit_confirm_refusal
    render :confirm_refusal
  end

  def update_confirm_refusal
    @form.assign_attributes(confirm_refusal_params)

    if @form.valid?
      if @form.confirmed?
        @consent.resolve_follow_up!(
          outcome: :confirmed,
          notes: confirm_refusal_params[:notes].to_s
        )

        @consent.notifier.send_confirmation(
          session: @session,
          triage: nil,
          sent_by: current_user
        )

        redirect_to session_patient_programme_consent_path,
                    flash: {
                      success: "Consent from #{@consent.name} updated."
                    }
      else
        redirect_to session_patient_programme_consent_path
      end
    else
      render :confirm_refusal, status: :unprocessable_content
    end
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
        .includes(:consent_form, :parent, :team, patient: :parent_relationships)
        .find(params[:id])
  end

  def set_consent_follow_up_form
    @form = ConsentFollowUpForm.new
  end

  def set_consent_confirm_refusal_form
    @form = ConsentConfirmRefusalForm.new
  end

  def update_patient_status
    @consent.invalidate_all_triages_and_patient_specific_directions!

    PatientStatusUpdater.call(patient: @patient)
  end

  def ensure_can_follow_up
    redirect_to action: :show unless @consent.can_follow_up?
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

  def follow_up_params
    params.fetch(:consent_follow_up_form, {}).permit(:decision_stands)
  end

  def confirm_refusal_params
    params.fetch(:consent_confirm_refusal_form, {}).permit(:confirmed, :notes)
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
end
