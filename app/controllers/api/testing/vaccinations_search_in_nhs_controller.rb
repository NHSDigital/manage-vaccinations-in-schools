# frozen_string_literal: true

class API::Testing::VaccinationsSearchInNHSController < API::Testing::BaseController
  POLL_INTERVAL = 0.25
  POLL_TIMEOUT = 300

  def create
    if params[:wait].present?
      EnqueueVaccinationsSearchInNHSJob.new.perform
      wait_for_search_jobs_to_complete
      render status: :ok
    else
      EnqueueVaccinationsSearchInNHSJob.perform_async
      render status: :accepted
    end
  end

  private

  # EnqueueVaccinationsSearchInNHSJob fans out to per-patient
  # SearchVaccinationRecordsInNHSJob jobs via perform_bulk. Poll
  # until Sidekiq workers have drained the queue so callers see
  # updated patient statuses when the response arrives.
  def wait_for_search_jobs_to_complete
    queue = Sidekiq::Queue.new("immunisations_api_search")
    deadline = Time.current + POLL_TIMEOUT

    # rubocop:disable Style/ZeroLengthPredicate -- Sidekiq::Queue has no #empty?
    sleep POLL_INTERVAL until queue.size.zero? || Time.current > deadline
    # rubocop:enable Style/ZeroLengthPredicate
  end
end
