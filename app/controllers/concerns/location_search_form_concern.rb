# frozen_string_literal: true

module LocationSearchFormConcern
  extend ActiveSupport::Concern

  include Pagy::Backend

  def set_location_search_form
    @form =
      LocationSearchForm.new(
        request_path: request.path,
        request_session: session,
        **location_search_form_params
      )
  end

  private

  def location_search_form_params
    params.permit(:_clear, :phase, :query)
  end
end
