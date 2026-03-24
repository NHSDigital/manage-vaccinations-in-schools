# frozen_string_literal: true

class DraftImportsController < ApplicationController
  before_action :set_draft_import
  before_action :set_location

  include WizardControllerConcern

  before_action :set_location_options, if: -> { current_step == :location }
  before_action :set_year_group_options, if: -> { current_step == :year_groups }

  skip_after_action :verify_policy_scoped

  def show
    authorize :import, :new?

    render_wizard
  end

  def update
    authorize :import, :create?

    @draft_import.assign_attributes(update_params)

    reload_steps

    render_wizard @draft_import
  end

  private

  def set_draft_import
    @draft_import = DraftImport.new(request_session: session, current_user:)
  end

  def set_location
    @location = @draft_import.location
  end

  def set_location_options
    @location_options = policy_scope(Location).gias_school
  end

  def set_year_group_options
    @year_group_options =
      @location.year_groups.map do |year_group|
        OpenStruct.new(
          value: year_group,
          label: helpers.format_year_group(year_group)
        )
      end
  end

  def set_steps
    self.steps = @draft_import.wizard_steps
  end

  def finish_wizard_path
    if @draft_import.is_class_import?
      new_class_import_path
    elsif @draft_import.is_cohort_import?
      new_cohort_import_path
    else
      new_immunisation_import_path
    end
  end

  def update_params
    step_param =
      if current_step == :location
        :location_id
      else
        current_step
      end

    {
      step_param => params.dig(:draft_import, step_param),
      :wizard_step => current_step
    }
  end
end
