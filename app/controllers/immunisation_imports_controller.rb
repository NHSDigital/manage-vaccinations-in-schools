# frozen_string_literal: true

class ImmunisationImportsController < ApplicationController
  include Pagy::Backend

  before_action :set_immunisation_import, only: %i[show]

  skip_after_action :verify_policy_scoped, only: %i[new create]

  helper_method :error_rows_limit

  def new
    @immunisation_import = authorize ImmunisationImport.new(team: current_team)
  end

  def create
    @immunisation_import =
      authorize ImmunisationImport.new(
                  team: current_team,
                  uploaded_by: current_user,
                  type:,
                  **immunisation_import_params
                )

    if @immunisation_import.save
      ProcessImportSidekiqJob.perform_async(
        @immunisation_import.to_global_id.to_s
      )
      redirect_to imports_path, flash: { success: "Import processing started" }
    else
      render :new, status: :unprocessable_content and return
    end
  end

  def show
    if @immunisation_import.rows_are_invalid?
      @immunisation_import.load_serialized_errors!(limit: error_rows_limit)
    end

    vaccination_records =
      @immunisation_import.vaccination_records.includes(
        :location,
        :session,
        patient: :school
      )

    @pagy, @vaccination_records = pagy(vaccination_records)

    @duplicates = vaccination_records.with_pending_changes.distinct

    render template: "imports/show",
           layout: "full",
           locals: {
             import: @immunisation_import
           }
  end

  private

  def type
    current_team.type
  end

  def set_immunisation_import
    @immunisation_import =
      authorize policy_scope(ImmunisationImport).find(params[:id])
  end

  def immunisation_import_params
    params.fetch(:immunisation_import, {}).permit(:csv)
  end

  def error_rows_limit = 100
end
