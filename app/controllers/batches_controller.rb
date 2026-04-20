# frozen_string_literal: true

class BatchesController < ApplicationController
  include TodaysBatchConcern

  before_action :set_vaccine
  before_action :set_batch, except: %i[new create]

  def new
    authorize Batch
    @form = BatchForm.new
  end

  def create
    batch =
      authorize Batch.archived.find_or_initialize_by(
                  team: current_team,
                  vaccine: @vaccine,
                  **batch_form_params
                )

    batch.archived_at = nil if batch.archived?

    @form = BatchForm.new(**batch_form_params, batch:)

    if expiry_validator.date_params_valid? && @form.save
      redirect_to vaccines_path,
                  flash: {
                    success: "Batch #{batch.number} added"
                  }
    else
      @form.expiry = expiry_validator.date_params_as_struct
      render :new, status: :unprocessable_content
    end
  end

  def make_default
    self.todays_batch = @batch
    redirect_to vaccines_path
  end

  def edit_archive
    render :archive
  end

  def update_archive
    @batch.archive!

    redirect_to vaccines_path, flash: { success: "Batch archived" }
  end

  private

  attr_reader :vaccine

  def set_vaccine
    @vaccine = policy_scope(Vaccine).find(params[:vaccine_id])
  end

  def set_batch
    @batch =
      authorize policy_scope(Batch).where(vaccine: @vaccine).find(params[:id])
  end

  def batch_form_params
    raw_params =
      params.expect(batch_form: %i[number expiry(3i) expiry(2i) expiry(1i)])

    {
      number: raw_params[:number],
      expiry:
        begin
          Date.new(
            raw_params["expiry(1i)"].to_i,
            raw_params["expiry(2i)"].to_i,
            raw_params["expiry(3i)"].to_i
          )
        rescue StandardError
          nil
        end
    }
  end

  def expiry_validator
    @expiry_validator ||=
      DateParamsValidator.new(
        field_name: :expiry,
        object: @form,
        params: params.expect(batch_form: %i[expiry(3i) expiry(2i) expiry(1i)])
      )
  end
end
