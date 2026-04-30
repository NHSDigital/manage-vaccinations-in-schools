# frozen_string_literal: true

class API::Testing::RefreshReportingController < API::Testing::BaseController
  def create
    if params[:wait].present?
      ReportingAPI::RefreshJob.new.perform
      render status: :ok
    else
      ReportingAPI::RefreshJob.perform_async
      render status: :accepted
    end
  end
end
