# frozen_string_literal: true

class CohortImportsController < ApplicationController
  include Pagy::Backend

  before_action :set_draft_import, only: %i[new create]
  before_action :set_cohort_import,
                only: %i[show approve cancel re_review imported_records]
  before_action :set_open_sections, only: %i[show]
  before_action :set_review_records, only: %i[re_review imported_records]

  skip_after_action :verify_policy_scoped, only: %i[new create]

  helper_method :error_rows_limit

  def new
    @cohort_import = authorize CohortImport.new(team: current_team)
  end

  def create
    @cohort_import =
      authorize CohortImport.new(
                  academic_year: @academic_year,
                  team: current_team,
                  uploaded_by: current_user,
                  **cohort_import_params
                )

    if @cohort_import.save
      ProcessImportJob.perform_later(@cohort_import)
      redirect_to imports_path, flash: { success: "Import processing started" }
    else
      render :new, status: :unprocessable_content and return
    end
  end

  def show
    if @cohort_import.rows_are_invalid? ||
         @cohort_import.changesets_are_invalid?
      @cohort_import.load_serialized_errors!(limit: error_rows_limit)
    end

    set_review_records if @cohort_import.in_review?

    if @cohort_import.in_re_review?
      redirect_to re_review_cohort_import_path(@cohort_import) and return
    end

    if @cohort_import.processed_at? || @cohort_import.partially_processed?
      @pagy, @patients = pagy(@cohort_import.patients.includes(:school))

      @duplicates =
        @patients.with_pending_changes_for_team(team: current_team).distinct

      @issues_text =
        @duplicates.each_with_object({}) do |patient, hash|
          changeset = @cohort_import.changesets.find_by(patient_id: patient.id)

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
        @cohort_import.changesets.includes(:patient).nhs_number_discrepancies

      @cancelled = @cohort_import.changesets.from_file.cancelled
      @skipped_school_moves =
        @cohort_import
          .changesets
          .includes(:patient, patient: :school)
          .from_file
          .skipped_school_move
    end

    render template: "imports/show",
           layout: "full",
           locals: {
             import: @cohort_import
           }
  end

  def re_review
    render template: "imports/re_review",
           layout: "full",
           locals: {
             import: @cohort_import
           }
  end

  def imported_records
    render template: "imports/imported_records",
           layout: "full",
           locals: {
             import: @cohort_import
           }
  end

  def approve
    @cohort_import.reviewed_by_user_ids << current_user.id
    @cohort_import.reviewed_at << Time.zone.now
    @cohort_import.committing!

    @cohort_import.commit_changesets(
      @cohort_import.changesets.from_file.ready_for_review
    )

    redirect_to imports_path, flash: { info: "Import started" }
  end

  def cancel
    @cohort_import.reviewed_by_user_ids << current_user.id
    @cohort_import.reviewed_at << Time.zone.now

    # some changesets were processed after first review, but the second review was cancelled
    if @cohort_import.changesets.processed.any?
      @cohort_import.update_columns(
        processed_at: Time.zone.now,
        status: :partially_processed
      )
      @cohort_import.save!
      @cohort_import.changesets.ready_for_review.find_each(&:cancelled!)

      @cohort_import.postprocess_rows!

      redirect_to imports_path, flash: { success: "Import partially completed" }
    else
      @cohort_import.update!(status: :cancelled)
      @cohort_import.changesets.each(&:cancelled!)

      redirect_to imports_path, flash: { success: "Import cancelled" }
    end
  end

  private

  def set_draft_import
    @draft_import = DraftImport.new(request_session: session, current_user:)
    @academic_year = @draft_import.academic_year
  end

  def set_cohort_import
    @cohort_import = authorize policy_scope(CohortImport).find(params[:id])
    @academic_year = @cohort_import.academic_year
  end

  def cohort_import_params
    params.fetch(:cohort_import, {}).permit(:csv)
  end

  def set_review_records
    @pagy, @patients = pagy(@cohort_import.patients.includes(:school))
    @inter_team =
      @cohort_import
        .changesets
        .includes(
          :school,
          patient: [
            :school,
            :patient_locations,
            :archive_reasons,
            {
              patient_locations: :location,
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
        @cohort_import.changesets.ready_for_review.new_patient.order(
          :row_number
        ),
        page_param: :new_records_page
      )
    @auto_matched_records =
      pagy(
        @cohort_import
          .changesets
          .ready_for_review
          .auto_match
          .where.not(id: @inter_team_ids)
          .order(:row_number),
        page_param: :auto_matched_records_page
      )
    @import_issues =
      pagy(
        @cohort_import
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
        @cohort_import
          .changesets
          .includes(:school, patient: :school)
          .ready_for_review
          .with_school_moves
          .where.not(id: @inter_team_ids)
          .order(:row_number),
        page_param: :school_moves_page
      )
    @skipped_school_moves =
      @cohort_import
        .changesets
        .includes(:patient, patient: :school)
        .ready_for_review
        .skipped_school_move
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
