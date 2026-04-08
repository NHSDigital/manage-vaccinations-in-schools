# frozen_string_literal: true

class CareplusExportsController < ApplicationController
  include Pagy::Backend

  layout "full"

  before_action :set_careplus_export, only: %i[show download]

  def index
    authorize CareplusExport
    scope =
      policy_scope(CareplusExport).includes(
        :careplus_export_vaccination_records
      ).order(created_at: :desc)
    @pagy, @exports = pagy(scope)
  end

  def show
    vaccination_records =
      @careplus_export
        .vaccination_records
        .includes(patient: :school)
        .order("patients.family_name, patients.given_name")
    @pagy, @vaccination_records = pagy(vaccination_records)
  end

  def download
    if @careplus_export.csv_data.blank?
      redirect_to careplus_export_path(@careplus_export),
                  flash: {
                    error: t(".no_file")
                  }
      return
    end

    send_data @careplus_export.csv_data,
              filename: @careplus_export.csv_filename,
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def set_careplus_export
    @careplus_export = authorize policy_scope(CareplusExport).find(params[:id])
  end
end
