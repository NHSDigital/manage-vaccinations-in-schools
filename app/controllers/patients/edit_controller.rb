# frozen_string_literal: true

class Patients::EditController < Patients::BaseController
  before_action :authorize_patient
  before_action :set_patient_merge_form,
                only: %i[update_nhs_number update_nhs_number_merge]
  before_action :set_existing_patient,
                only: %i[update_nhs_number update_nhs_number_merge]
  before_action :set_eligible_schools, only: %i[edit_school update_school]

  def edit_nhs_number
    render :nhs_number
  end

  def update_nhs_number
    @patient.nhs_number = nhs_number.presence

    redirect_to edit_patient_path(@patient) and return unless @patient.changed?

    render :nhs_number_merge and return if @existing_patient

    @patient.invalidated_at = nil

    if @patient.save
      PatientUpdateFromPDSJob.perform_later(@patient)

      redirect_to edit_patient_path(@patient)
    else
      render :nhs_number, status: :unprocessable_content
    end
  end

  def edit_ethnic_group
    render :ethnic_group
  end

  def update_ethnic_group
    @patient.ethnic_group = ethnic_group

    redirect_to edit_patient_path(@patient) and return unless @patient.changed?

    if @patient.save
      redirect_to edit_ethnic_background_patient_path(@patient)
    else
      render :ethnic_group, status: :unprocessable_content
    end
  end

  def edit_ethnic_background
    render :ethnic_background
  end

  def update_ethnic_background
    @patient.ethnic_background = ethnic_background
    @patient.ethnic_background_other = ethnic_background_other

    redirect_to edit_patient_path(@patient) and return unless @patient.changed?

    if @patient.save
      redirect_to edit_patient_path(@patient)
    else
      render :ethnic_background, status: :unprocessable_content
    end
  end

  def update_nhs_number_merge
    if @form.save
      redirect_to edit_patient_path(@existing_patient)
    else
      render :nhs_number_merge, status: :unprocessable_entity
    end
  end

  def edit_school
    render :school
  end

  def update_school
    @patient.school_id = school_id

    redirect_to edit_patient_path(@patient) and return unless @patient.changed?

    if @patient.valid?
      SchoolMove.new(
        academic_year: AcademicYear.current,
        patient: @patient,
        school: @patient.school
      ).confirm!(user: current_user)

      redirect_to edit_patient_path(@patient)
    else
      render :school, status: :unprocessable_content
    end
  end

  private

  def authorize_patient
    authorize @patient
  end

  def set_patient_merge_form
    @form = PatientMergeForm.new(current_user:, patient: @patient, nhs_number:)
  end

  def set_existing_patient
    @existing_patient = @form.existing_patient
  end

  def nhs_number
    params.dig(:patient, :nhs_number) ||
      params.dig(:patient_merge_form, :nhs_number)
  end

  def ethnic_group
    params.dig(:patient, :ethnic_group)
  end

  def ethnic_background
    params.dig(:patient, :ethnic_background)
  end

  def ethnic_background_other
    params.dig(:patient, :ethnic_background_other)
  end

  def school_id
    params.dig(:patient, :school_id)
  end

  def set_eligible_schools
    year_group = @patient.birth_academic_year.to_year_group
    @eligible_schools =
      current_team
        .locations
        .school
        .joins(:location_year_groups)
        .where(location_year_groups: { value: year_group })
        .distinct
  end
end
