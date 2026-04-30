# frozen_string_literal: true

class ClassImportsController < ApplicationController
  include Pagy::Backend

  before_action :set_draft_import, only: %i[new create]
  before_action :set_class_import,
                only: %i[show approve cancel re_review imported_records]
  before_action :set_open_sections, only: %i[show]
  before_action :set_review_records, only: %i[re_review imported_records]

  skip_after_action :verify_policy_scoped, only: %i[new create]

  helper_method :error_rows_limit

  def new
    @class_import = authorize ClassImport.new(team: current_team)
  end

  def create
    @class_import =
      authorize ClassImport.new(
                  academic_year: @academic_year,
                  location: @location,
                  team: current_team,
                  uploaded_by: current_user,
                  year_groups: @draft_import.year_groups,
                  **class_import_params
                )

    if @class_import.save
      ProcessImportJob.perform_later(@class_import)
      redirect_to imports_path, flash: { success: "Import processing started" }
    else
      render :new, status: :unprocessable_content and return
    end
  end

  def show
    if @class_import.rows_are_invalid? || @class_import.changesets_are_invalid?
      @class_import.load_serialized_errors!(limit: error_rows_limit)
    end

    set_review_records if @class_import.in_review?

    if @class_import.in_re_review?
      redirect_to re_review_class_import_path(@class_import) and return
    end

    if @class_import.processed_at? || @class_import.partially_processed?
      @pagy, @patients = pagy(@class_import.patients.includes(:school))

      @duplicates =
        @patients.with_pending_changes_for_team(team: current_team).distinct

      @issues_text =
        @duplicates.each_with_object({}) do |patient, hash|
          changeset = @class_import.changesets.find_by(patient_id: patient.id)

          issue_groups =
            helpers.issue_categories_for(patient.pending_changes.keys)

          hash[patient.full_name] = if changeset&.matched_on_nhs_number
            "Matched on NHS number. #{issue_groups.to_sentence.capitalize}" +
              (issue_groups.size == 1 ? " does not match." : " do not match.")
          else
            "Possible match found. Review and confirm."
          end
        end

      @nhs_discrepancies =
        @class_import.changesets.includes(:patient).nhs_number_discrepancies

      @cancelled = @class_import.changesets.from_file.cancelled
    end

    render template: "imports/show",
           layout: "full",
           locals: {
             import: @class_import
           }
  end

  def re_review
    render template: "imports/re_review",
           layout: "full",
           locals: {
             import: @class_import
           }
  end

  def imported_records
    render template: "imports/imported_records",
           layout: "full",
           locals: {
             import: @class_import
           }
  end

  def approve
    @class_import.reviewed_by_user_ids << current_user.id
    @class_import.reviewed_at << Time.zone.now
    @class_import.committing!

    @class_import.changesets.not_from_file.ready_for_review.update_all(
      status: :committing
    )

    if @class_import.changesets.from_file.ready_for_review.any?
      @class_import.commit_changesets(
        @class_import.changesets.from_file.ready_for_review
      )
    elsif @class_import.changesets.cancelled.any?
      @class_import.update_columns(
        status: :partially_processed,
        processed_at: Time.zone.now
      )
      @class_import.postprocess_rows!
    else
      @class_import.update_columns(
        status: :processed,
        processed_at: Time.zone.now
      )
      @class_import.postprocess_rows!
    end

    redirect_to imports_path, flash: { info: "Import started" }
  end

  def cancel
    @class_import.reviewed_by_user_ids << current_user.id
    @class_import.reviewed_at << Time.zone.now

    # some changesets were processed after first review, but the second review was cancelled
    if @class_import.changesets.processed.any?
      @class_import.update_columns(
        processed_at: Time.zone.now,
        status: :partially_processed
      )
      @class_import.save!
      @class_import.changesets.from_file.ready_for_review.update_all(
        status: :cancelled
      )
      @class_import.changesets.not_from_file.ready_for_review.update_all(
        status: :committing
      )

      @class_import.postprocess_rows!

      redirect_to imports_path, flash: { success: "Import partially completed" }
    else
      @class_import.update!(status: :cancelled)
      @class_import.changesets.each(&:cancelled!)

      redirect_to imports_path, flash: { success: "Import cancelled" }
    end
  end

  private

  def set_draft_import
    @draft_import = DraftImport.new(request_session: session, current_user:)
    @location = @draft_import.location
    @academic_year = @draft_import.academic_year
  end

  def set_class_import
    @class_import =
      authorize policy_scope(ClassImport).includes(:location).find(params[:id])
    @location = @class_import.location
    @academic_year = @class_import.academic_year
  end

  def class_import_params
    params.fetch(:class_import, {}).permit(:csv)
  end

  def set_review_records
    @pagy, @patients = pagy(@class_import.patients.includes(:school))
    @inter_team =
      @class_import
        .changesets
        .includes(
          :school,
          patient: [
            :school,
            :school_moves,
            :archive_reasons,
            {
              patient_locations: :school,
              school: {
                team_locations: :team
              },
              school_moves: :teams
            }
          ]
        )
        .from_file
        .ready_for_review
        .select(&:inter_team_move?)
    @inter_team_ids = @inter_team.map(&:id) || []
    @new_records =
      pagy(
        @class_import.changesets.ready_for_review.new_patient.order(
          :row_number
        ),
        page_param: :new_records_page
      )
    @auto_matched_records =
      pagy(
        @class_import
          .changesets
          .ready_for_review
          .auto_match
          .where.not(id: @inter_team_ids)
          .order(:row_number),
        page_param: :auto_matched_records_page
      )
    @import_issues =
      pagy(
        @class_import
          .changesets
          .includes(:patient)
          .ready_for_review
          .import_issue
          .where.not(id: @inter_team_ids)
          .order(:row_number),
        page_param: :import_issues_page
      )
    @school_moves =
      pagy(
        @class_import
          .changesets
          .includes(:school, patient: :school)
          .ready_for_review
          .with_school_moves
          .where.not(id: @inter_team_ids)
          .order(:row_number),
        page_param: :school_moves_page
      )
  end

  def error_rows_limit = 100

  def set_open_sections
    @open_sections =
      params
        .keys
        .map { |key| key.match(/(.+)_page/) }
        .compact
        .map { |match| match[1].to_sym }
  end
end
