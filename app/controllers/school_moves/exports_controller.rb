# frozen_string_literal: true

class SchoolMoves::ExportsController < ApplicationController
  skip_after_action :verify_policy_scoped

  def new
    authorize Export.new(team: current_team, user: current_user)
    @form = SchoolMovesExportForm.new
  end

  def create
    @form = SchoolMovesExportForm.new(**create_params)

    if from_and_to_dates_valid? && @form.valid?
      exportable =
        SchoolMovesExport.new(
          date_from: @form.date_from,
          date_to: @form.date_to
        )
      @export =
        Export.from_exportable(
          exportable,
          user: current_user,
          team: current_team
        )

      authorize @export

      @export.save!
      GenerateExportJob.perform_later(@export)

      flash[:success] = {
        heading: t("exports_flash.heading"),
        heading_link_text: t("exports_flash.heading_link_text"),
        heading_link_href: downloads_path
      }
      redirect_to downloads_path
    else
      authorize Export.new(team: current_team, user: current_user)

      @form.date_from = date_from_validator.date_params_as_struct
      @form.date_to = date_to_validator.date_params_as_struct
      render :new, status: :unprocessable_content
    end
  end

  private

  def create_params
    raw = params.fetch(:school_moves_export_form, {})
    {
      date_from:
        begin
          Date.new(
            raw["date_from(1i)"].to_i,
            raw["date_from(2i)"].to_i,
            raw["date_from(3i)"].to_i
          )
        rescue StandardError
          nil
        end,
      date_to:
        begin
          Date.new(
            raw["date_to(1i)"].to_i,
            raw["date_to(2i)"].to_i,
            raw["date_to(3i)"].to_i
          )
        rescue StandardError
          nil
        end
    }
  end

  def from_and_to_dates_valid?
    date_from_validator.date_params_valid? &&
      date_to_validator.date_params_valid?
  end

  def date_from_validator
    @date_from_validator ||=
      DateParamsValidator.new(
        field_name: :date_from,
        object: @form,
        params: params.fetch(:school_moves_export_form, {})
      )
  end

  def date_to_validator
    @date_to_validator ||=
      DateParamsValidator.new(
        field_name: :date_to,
        object: @form,
        params: params.fetch(:school_moves_export_form, {})
      )
  end
end
