# frozen_string_literal: true

module SessionSearchFormConcern
  extend ActiveSupport::Concern

  include Pagy::Backend

  def set_session_search_form
    @form =
      SessionSearchForm.new(
        request_path: request.path,
        request_session: session,
        **session_search_form_params
      )
  end

  private

  def session_search_form_params
    params.permit(
      :_clear,
      :academic_year,
      :query,
      :status,
      :type,
      programmes: []
    )
  end
end
