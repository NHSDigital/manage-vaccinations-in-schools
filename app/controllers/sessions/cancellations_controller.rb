# frozen_string_literal: true

class Sessions::CancellationsController < Sessions::BaseController
  before_action :authorize_session

  def show
    @booked_children_count = @session.patients.count
  end

  def create
    if @session.cancel(current_user)
      flash[:success] = cancellation_success_message
      redirect_to sessions_path
    else
      flash[:error] = "This session cannot be cancelled"
      redirect_to session_path(@session)
    end
  end

  private

  def authorize_session
    authorize @session, :cancel?
  end

  def cancellation_success_message
    programmes = @session.programmes.map(&:name).to_sentence
    date = helpers.session_dates(@session)

    "#{programmes} clinic at #{@session.location.name} on #{date} cancelled"
  end
end
