# frozen_string_literal: true

class API::Testing::ReportingRefreshController < API::Testing::BaseController
  def create
    if params[:wait].present?
      ReportingAPI::RefreshJob.perform_now
      render status: :ok
    else
      ReportingAPI::RefreshJob.perform_later
      render status: :accepted
    end
  end
end
