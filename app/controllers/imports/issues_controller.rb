# frozen_string_literal: true

class Imports::IssuesController < ApplicationController
  before_action :set_import_issues
  before_action :set_record, only: %i[show update]
  before_action :set_vaccination_record, only: %i[show update]
  before_action :set_patient, only: %i[show update]
  before_action :set_patient_with_pending_changes, only: :show
  before_action :set_form, only: %i[show update]
  before_action :set_type

  layout "full"

  def index
    authorize %i[import issue]
  end

  def show
  end

  def update
    if @form.save
      redirect_target = params[:return_to].presence || imports_issues_path

      redirect_to redirect_target, flash: { success: "Record updated" }
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_import_issues
    @vaccination_records =
      policy_scope(VaccinationRecord).with_pending_changes.includes(
        :location,
        :performed_by_user,
        :vaccine,
        session: :location,
        patient: %i[gp_practice school]
      )

    @patients =
      policy_scope(Patient).with_pending_changes_for_team(
        team: current_team
      ).includes(
        :gp_practice,
        :school,
        :school_moves,
        parent_relationships: [:parent]
      )

    @import_issues =
      (@vaccination_records + @patients).uniq do |record|
        record.is_a?(VaccinationRecord) ? record.patient : record
      end
  end

  def set_record
    @record =
      if params[:type] == "vaccination-record"
        @vaccination_records.with_discarded.find(params[:id])
      else
        @patients.includes(:gp_practice, :school, :school_moves, :parents).find(
          params[:id]
        )
      end

    authorize @record, policy_class: Import::IssuePolicy
  end

  def set_vaccination_record
    @vaccination_record = @record if @record.is_a?(VaccinationRecord)
  end

  def set_patient
    @patient = @record.is_a?(VaccinationRecord) ? @record.patient : @record
  end

  def set_patient_with_pending_changes
    @patient_with_pending_changes =
      @patient.with_pending_changes.tap do |patient_with_pending_changes|
        patient_with_pending_changes.strict_loading!(false)
      end
  end

  def set_form
    apply_changes = params.dig(:import_duplicate_form, :apply_changes)

    @form =
      ImportDuplicateForm.new(current_team:, object: @record, apply_changes:)
  end

  def set_type
    @type =
      (
        if @record.is_a?(VaccinationRecord)
          "vaccination"
        else
          "child"
        end
      )
    @existing_or_deleted =
      (
        if @record.is_a?(VaccinationRecord) && @record.discarded_at
          "archived"
        else
          "existing"
        end
      )
  end
end
