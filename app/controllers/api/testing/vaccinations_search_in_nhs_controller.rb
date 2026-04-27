# frozen_string_literal: true

class API::Testing::VaccinationsSearchInNHSController < API::Testing::BaseController
  def create
    if params[:wait].present?
      EnqueueVaccinationsSearchInNHSJob.perform_now
      render status: :ok
    else
      EnqueueVaccinationsSearchInNHSJob.perform_later
      render status: :accepted
    end
  end
end
