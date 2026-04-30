# frozen_string_literal: true

class SessionsController < ApplicationController
  include SessionSearchFormConcern

  before_action :set_session_search_form, only: :index
  before_action :set_session, except: %i[index new]

  skip_after_action :verify_policy_scoped, only: :new

  def index
    authorize Session

    @programmes = current_user.selected_team.programmes

    scope =
      policy_scope(Session).includes(:location, :session_programme_year_groups)

    sessions = @form.apply(scope)

    @pagy, @sessions = pagy_array(sessions)

    @patient_count_by_session_id = patient_counts_for_sessions(@sessions)

    render layout: "full"
  end

  def new
    authorize Session

    @draft_session = DraftSession.new(request_session: session, current_user:)

    @draft_session.clear_attributes
    @draft_session.assign_attributes(create_params)

    if params[:school_id].present?
      @draft_session.location_id = params[:school_id]
      @draft_session.return_to = "school"
    else
      @draft_session.return_to = "sessions"
    end

    @draft_session.save!

    first_step = params[:school_id].present? ? "programmes" : Wicked::FIRST_STEP
    redirect_to draft_session_path(first_step)
  end

  def show
    render layout: "session"
  end

  def edit
    @draft_session = DraftSession.new(request_session: session, current_user:)

    @draft_session.return_to = params[:return_to]
    @draft_session.read_from!(@session)

    redirect_to draft_session_path("confirm")
  end

  def import
    draft_import = DraftImport.new(request_session: session, current_user:)

    draft_import.clear_attributes
    draft_import.update!(location: @session.location, type: "class")

    steps = draft_import.wizard_steps
    steps.delete(:type)
    steps.delete(:location)

    redirect_to draft_import_path(I18n.t(steps.first, scope: :wicked))
  end

  def make_in_progress
    valid_date_range = @session.academic_year.to_academic_year_date_range

    date = Date.current

    if date.in?(valid_date_range)
      @session.update!(dates: (@session.dates + [date]).sort.uniq)
      redirect_to session_path, flash: { success: "Session is now in progress" }
    else
      redirect_to session_path,
                  flash: {
                    error: "Today is not a valid date for this session"
                  }
    end
  end

  private

  def set_session
    @session = authorize policy_scope(Session).find_by!(slug: params[:slug])
  end

  def patient_counts_for_sessions(sessions)
    Patient
      .joins_sessions
      .joins_session_programme_year_groups
      .where("sessions.id = ANY(ARRAY[?]::bigint[])", sessions.map(&:id))
      .group("sessions.id")
      .count("DISTINCT patients.id")
  end

  def create_params
    {
      academic_year: AcademicYear.pending,
      session_dates: [DraftSessionDate.new],
      team_id: current_team.id,
      national_protocol_enabled: false,
      psd_enabled: false,
      requires_registration: true,
      outbreak: false
    }
  end
end
