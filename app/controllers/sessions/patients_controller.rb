# frozen_string_literal: true

class Sessions::PatientsController < Sessions::BaseController
  include PatientSearchFormConcern

  before_action :set_patient_search_form, only: :show
  before_action :set_registration_statuses, only: :show
  before_action :set_patient, only: :register

  layout "session"

  def show
    scope =
      @session.patients.includes_statuses.includes(
        :registration_statuses,
        notes: :created_by
      )

    patients = @form.apply(scope)

    @pagy, @patients = pagy(patients)
  end

  def register
    attendance_record =
      @patient.attendance_records.find_or_initialize_by(
        location: @session.location,
        date: Date.current
      )

    attendance_record.session = @session

    authorize attendance_record, :create?

    ActiveRecord::Base.transaction do
      attendance_record.update!(attending: params[:status] == "present")
      PatientStatusUpdater.call(patient: @patient)
    end

    name = @patient.full_name

    flash[:info] = if attendance_record.attending?
      t("attendance_flash.present", name:)
    else
      t("attendance_flash.absent", name:)
    end

    redirect_to session_patients_path(@session)
  end

  private

  def set_registration_statuses
    @registration_statuses =
      if @session.today? && @session.requires_registration?
        Patient::RegistrationStatus.statuses.keys
      else
        []
      end
  end

  def set_patient
    @patient = policy_scope(Patient).find(params[:patient_id])
  end
end
