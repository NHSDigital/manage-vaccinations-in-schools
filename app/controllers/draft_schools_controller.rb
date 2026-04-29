# frozen_string_literal: true

class DraftSchoolsController < ApplicationController
  before_action :set_context
  before_action :set_draft_school
  before_action :set_school
  before_action :redirect_if_session_cleared, only: %i[show update]

  include WizardControllerConcern

  before_action :set_school_options, if: -> { current_step == :school }
  before_action :set_name, if: -> { current_step == :confirm_urn }
  before_action :set_address,
                if: -> { %i[details confirm_urn].include?(current_step) }
  before_action :set_phases, if: -> { current_step == :phase }
  before_action :set_year_groups, if: -> { current_step == :year_groups }
  before_action :set_back_link_path

  skip_after_action :verify_policy_scoped

  def show
    authorize Location, :new?, policy_class: SchoolPolicy

    render_wizard
  end

  def update
    authorize Location, :create?, policy_class: SchoolPolicy

    @draft_school.assign_attributes(update_params)

    case current_step
    when :confirm_urn
      handle_confirm_urn
    when :school
      handle_school
    when :confirm
      handle_confirm
    end

    jump_to("confirm") if @draft_school.editing? && current_step != :confirm

    reload_steps

    render_wizard @draft_school
  end

  private

  def set_draft_school
    @draft_school =
      DraftSchool.new(
        request_session: session,
        current_user:,
        current_team:,
        context: @context
      )
  end

  def set_context
    @context = params[:context] || session.dig(:draft_school, :context)
  end

  def set_school
    @school = Location.new
  end

  def set_school_options
    @school_options =
      policy_scope(Location)
        .gias_school
        .joins(:team_locations)
        .where(team_locations: { academic_year: AcademicYear.pending })
        .distinct
        .order(:urn, :name)
  end

  def set_steps
    self.steps = @draft_school.wizard_steps
  end

  def set_address
    source = @draft_school.source_location

    @draft_school.address_line_1 ||= source&.address_line_1
    @draft_school.address_line_2 ||= source&.address_line_2
    @draft_school.address_town ||= source&.address_town
    @draft_school.address_postcode ||= source&.address_postcode
  end

  def set_name
    @draft_school.name ||= @draft_school.source_location&.name
  end

  def set_phases
    @phases = Location::PHASES
  end

  def set_year_groups
    @year_groups =
      Location::YearGroup::DEFAULT_VALUE_RANGE.map do |n|
        OpenStruct.new(id: n, name: helpers.format_year_group(n))
      end
  end

  def handle_confirm_urn
    jump_to("urn") if @draft_school.confirm_school == "no"
  end

  def set_back_link_path
    @back_link_path =
      if @draft_school.editing? && current_step != :confirm
        wizard_path("confirm")
      elsif first_step_of_flow?
        schools_team_path
      else
        previous_wizard_path
      end
  end

  def first_step_of_flow?
    (current_step == :confirm && @draft_school.editing?) ||
      current_step == @draft_school.wizard_steps.first
  end

  def handle_school
    @draft_school.clear!
    @draft_school.assign_attributes(update_params)
  end

  def handle_confirm
    return unless @draft_school.save

    @draft_school.assign_attributes(update_params)

    source_school = @draft_school.source_location

    if @draft_school.editing?
      @draft_school.write_to!(source_school)

      source_school.save!

      if @draft_school.selected_year_groups.present?
        academic_year = AcademicYear.pending
        source_school.import_year_groups!(
          @draft_school.year_groups,
          academic_year:,
          source: "manual"
        )
        source_school.import_default_programme_year_groups!(
          current_team.programmes,
          academic_year:
        )
      end

      flash[:success] = "#{source_school.name} has been updated."
    elsif @draft_school.add_school_context?
      # Add all sites of the school to the team
      schools = @draft_school.schools_with_urn
      ActiveRecord::Base.transaction do
        academic_year = AcademicYear.pending

        schools.each do |school|
          school.attach_to_team!(current_team, academic_year:)
          source_school.import_year_groups!(
            @draft_school.year_groups,
            academic_year:,
            source: "manual"
          )
          school.import_default_programme_year_groups!(
            current_team.programmes,
            academic_year:
          )
        end
      end

      school_names = schools.map(&:name)
      flash[
        :success
      ] = "#{school_names.to_sentence} #{school_names.count > 1 ? "have" : "has"} been added to your team."
    else
      # Add site flow
      @school = source_school.dup

      @school.assign_attributes(
        urn: @draft_school.resolved_urn,
        site: @draft_school.next_site_letter,
        name: @draft_school.name,
        address_line_1: @draft_school.address_line_1,
        address_line_2: @draft_school.address_line_2,
        address_town: @draft_school.address_town,
        address_postcode: @draft_school.address_postcode
      )

      ActiveRecord::Base.transaction do
        @school.save!
        academic_year = AcademicYear.pending

        source_school
          .teams_for_academic_year(academic_year)
          .each do |team|
            @school.attach_to_team!(team, academic_year:)
            @school.import_year_groups!(
              @draft_school.year_groups,
              academic_year:,
              source: "manual"
            )
            @school.import_default_programme_year_groups!(
              team.programmes,
              academic_year:
            )
          end

        source_school.update!(site: "A") if source_school.site.nil?
      end

      flash[:success] = "#{@school.name} has been added to your team."
    end

    @draft_school.clear!
  end

  def finish_wizard_path
    schools_team_path
  end

  def update_params
    permitted_attributes = {
      urn: [:urn],
      confirm_urn: [:confirm_school],
      school: [:parent_urn_and_site],
      details: %i[
        name
        address_line_1
        address_line_2
        address_town
        address_postcode
      ],
      phase: [:phase],
      year_groups: [{ year_groups: [] }],
      confirm: []
    }.fetch(current_step)

    params
      .fetch(:draft_school, {})
      .permit(permitted_attributes)
      .merge(wizard_step: current_step, context: @context)
  end

  def redirect_if_session_cleared
    return if params[:id] == "wicked_finish"
    return if params[:id] == "urn" # Allow URN entry step
    return if params[:id] == "school" # Allow school selection step even with blank URN
    if session[:draft_school].present? && @draft_school.resolved_urn.present?
      return
    end

    redirect_to schools_team_path if @draft_school.resolved_urn.blank?
  end
end
