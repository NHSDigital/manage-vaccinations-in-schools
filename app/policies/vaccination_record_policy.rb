# frozen_string_literal: true

class VaccinationRecordPolicy < ApplicationPolicy
  def index? = team.is_sais_team?

  def create?
    return true if user.is_nurse? || user.is_prescriber?
    return false unless user.is_healthcare_assistant?
    return true if patient.nil?
    return false if session.nil?

    vaccine_criteria = patient.vaccine_criteria(programme:, academic_year:)

    can_create_with_psd?(vaccine_criteria) ||
      can_create_with_national_protocol?(vaccine_criteria) ||
      can_create_with_pgd_supply?(vaccine_criteria)
  end

  def show? = team.is_sais_team?

  def update?
    if team.has_point_of_care_access?
      (
        record.performed_by_user_id == user.id || user.is_nurse? ||
          user.is_prescriber?
      ) &&
        (record.sourced_from_service? || record.sourced_from_manual_report?) &&
        record.performed_ods_code == user.selected_organisation.ods_code
    elsif team.has_national_reporting_access?
      record.sourced_from_national_reporting? &&
        record.immunisation_imports.any? { it.team_id == team.id }
    else
      false
    end
  end

  def confirm_destroy? = destroy?

  def destroy?
    user.can_perform_local_system_administration? &&
      !record.sourced_from_nhs_immunisations_api?
  end

  private

  delegate :patient, :session, :programme, :programme_type, to: :record
  delegate :academic_year, to: :session

  def can_create_with_psd?(vaccine_criteria)
    session.psd_enabled? &&
      vaccine_criteria.vaccine_methods.any? do |vaccine_method|
        patient.has_patient_specific_direction?(
          academic_year:,
          programme_type:,
          team: session.team,
          vaccine_method:
        )
      end
  end

  def can_create_with_national_protocol?(vaccine_criteria)
    session.national_protocol_enabled? &&
      vaccine_criteria.vaccine_methods.include?("injection")
  end

  def can_create_with_pgd_supply?(vaccine_criteria)
    session.pgd_supply_enabled? &&
      vaccine_criteria.vaccine_methods.include?("nasal")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if team.nil?

      scope
        .kept
        .joins(
          "INNER JOIN patient_teams on patient_teams.patient_id = vaccination_records.patient_id"
        )
        .where(patient_teams: { team_id: team.id })
    end
  end
end
