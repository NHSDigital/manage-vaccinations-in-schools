# frozen_string_literal: true

class PatientSessions::BaseController < ApplicationController
  before_action :set_session
  before_action :set_academic_year
  before_action :set_patient
  before_action :set_patient_location
  before_action :set_programme
  before_action :set_breadcrumb_item

  layout "three_quarters"

  private

  def set_session
    @session =
      authorize policy_scope(Session).includes(
                  :location,
                  :session_programme_year_groups
                ).find_by!(slug: params.fetch(:session_slug, params[:slug])),
                :show?
  end

  def set_academic_year
    @academic_year = @session.academic_year
  end

  def set_patient
    @patient =
      authorize policy_scope(Patient)
                  .includes_statuses
                  .includes(parent_relationships: :parent)
                  .find(params.fetch(:patient_id, params[:id])),
                :show?
  end

  def set_patient_location
    @patient_location =
      PatientLocation.find_by!(
        patient: @patient,
        school: @session.location,
        academic_year: @session.academic_year
      )
  end

  def set_programme
    requested_type = params[:programme_type].presence || params[:type].presence
    return unless requested_type

    programme =
      @session
        .programmes_for(patient: @patient)
        .find { it.variants.any? { |v| v.to_param == requested_type } }

    raise ActiveRecord::RecordNotFound if programme.nil?

    disease_types =
      @patient.programme_status(
        programme,
        academic_year: @session.academic_year
      ).disease_types

    @programme = programme.variant_for(disease_types:)
  end

  def set_breadcrumb_item
    return_to = params[:return_to]
    return nil if return_to.blank?

    known_return_to = %w[patients register record]
    return unless return_to.in?(known_return_to)

    @breadcrumb_item = {
      text: t(return_to, scope: %i[sessions tabs]),
      href: send(:"session_#{return_to}_path")
    }
  end

  def record_access_log_entry
    @patient.access_log_entries.create!(
      user: current_user,
      controller: "patient_sessions",
      action: access_log_entry_action
    )
  end
end
