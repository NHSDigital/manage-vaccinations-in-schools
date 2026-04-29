# frozen_string_literal: true

class CareplusReportsController < ApplicationController
  include Pagy::Backend

  layout "full"

  before_action :set_careplus_report, only: %i[show download]

  def index
    authorize CareplusReport
    scope = policy_scope(CareplusReport).order(created_at: :desc)
    @pagy, @careplus_reports = pagy(scope)
    @careplus_report_records_count_by_report_id =
      CareplusReportVaccinationRecord
        .where(careplus_report_id: @careplus_reports.select(:id))
        .group(:careplus_report_id)
        .count
  end

  def show
    vaccination_records =
      @careplus_report
        .vaccination_records
        .includes(patient: :school)
        .order("patients.family_name, patients.given_name")
    @pagy, @vaccination_records = pagy(vaccination_records)
  end

  def download
    if @careplus_report.csv_data.blank?
      redirect_to careplus_report_path(@careplus_report),
                  flash: {
                    error: t(".no_file")
                  }
      return
    end

    send_data @careplus_report.csv_data,
              filename: @careplus_report.csv_filename,
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def set_careplus_report
    @careplus_report = authorize(policy_scope(CareplusReport).find(params[:id]))
  end
end
