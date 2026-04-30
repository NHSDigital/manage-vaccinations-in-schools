# frozen_string_literal: true

class ExportsController < ApplicationController
  skip_after_action :verify_policy_scoped

  def download
    @export = current_team.exports.find(params[:id])
    authorize @export
    return head :forbidden unless @export.ready?

    send_data @export.file_data,
              type: @export.content_type,
              filename: @export.filename,
              disposition: :attachment
  end
end
