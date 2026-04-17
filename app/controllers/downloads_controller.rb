# frozen_string_literal: true

class DownloadsController < ApplicationController
  include Pagy::Backend

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  TYPE_FILTERS = { "offline_session" => %w[LocationPatientsExport SessionPatientsExport] }.freeze

  def index
    @type = params[:type].presence_in(TYPE_FILTERS.keys)

    scope = current_team.exports.order(created_at: :desc)
    scope = scope.where(exportable_type: TYPE_FILTERS[@type]) if @type.present?

    @pagy, @exports = pagy(scope.includes(:exportable, :user), limit: 20)

    render layout: "full"
  end
end
