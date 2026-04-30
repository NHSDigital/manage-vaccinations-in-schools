# frozen_string_literal: true

class Sessions::ExportsController < ApplicationController
  before_action :set_session

  skip_after_action :verify_policy_scoped

  def create
    exportable = SessionPatientsExport.new(session: @session)
    @export =
      Export.from_exportable(exportable, user: current_user, team: current_team)

    authorize @export

    @export.save!

    GenerateExportJob.perform_later(@export)

    flash[:success] = {
      heading: t("exports_flash.heading"),
      heading_link_text: t("exports_flash.heading_link_text"),
      heading_link_href: downloads_path
    }
    redirect_to session_path(@session)
  end

  private

  def set_session
    @session =
      authorize(
        policy_scope(Session).find_by!(slug: params[:session_slug]),
        :show?
      )
  end
end
