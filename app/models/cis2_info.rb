# frozen_string_literal: true

class CIS2Info
  include RequestSessionPersistable

  NURSE_ROLES = %w[S8000:G8000:R8001 S8000:G8000:R8003].freeze
  MEDICAL_SECRETARY_ROLES = %w[S8000:G8001:R8006 S8001:G8002:R8008].freeze
  SUPPORT_ROLE = "S8001:G8005:R8015"

  SUPPORT_WORKGROUP = "mavissupport"

  def self.support_organisation
    Settings.cis2.support_organisation
  end

  ACCESS_SENSITIVE_FLAGGED_RECORDS_ACTIVITY_CODE = "B1611"
  INDEPENDENT_PRESCRIBING_ACTIVITY_CODE = "B0420"
  LOCAL_SYSTEM_ADMINISTRATION_ACTIVITY_CODE = "B0062"
  PERSONAL_MEDICATION_ADMINISTRATION_ACTIVITY_CODE = "B0428"
  VIEW_DETAILED_HEALTH_RECORDS_ACTIVITY_CODE = "B0360"
  VIEW_SHARED_NON_PATIENT_IDENTIFIABLE_INFORMATION_ACTIVITY_CODE = "B1570"

  attribute :organisation_name
  attribute :organisation_code
  attribute :role_name
  attribute :role_code
  attribute :activity_codes, array: true
  attribute :workgroups, array: true
  attribute :team_workgroup
  attribute :has_other_roles, :boolean

  def present? = attributes.compact_blank.present?

  def organisation
    @organisation ||=
      if (ods_code = organisation_code).present?
        Organisation.find_by(ods_code:)
      end
  end

  def team
    @team ||=
      if (workgroup = team_workgroup).present? && workgroups.include?(workgroup)
        Team.find_by(organisation:, workgroup:)
      end
  end

  def has_valid_workgroup? =
    organisation&.teams&.exists?(workgroup: workgroups) || false

  def is_medical_secretary?
    MEDICAL_SECRETARY_ROLES.include?(role_code)
  end

  def is_nurse?
    NURSE_ROLES.include?(role_code)
  end

  def is_healthcare_assistant?
    MEDICAL_SECRETARY_ROLES.include?(role_code) &&
      activity_codes.include?(PERSONAL_MEDICATION_ADMINISTRATION_ACTIVITY_CODE)
  end

  def is_prescriber?
    activity_codes.include?(INDEPENDENT_PRESCRIBING_ACTIVITY_CODE)
  end

  def is_superuser?
    can_access_sensitive_flagged_records? ||
      can_perform_local_system_administration?
  end

  def can_access_sensitive_flagged_records?
    activity_codes.include?(ACCESS_SENSITIVE_FLAGGED_RECORDS_ACTIVITY_CODE)
  end

  def can_perform_local_system_administration?
    activity_codes.include?(LOCAL_SYSTEM_ADMINISTRATION_ACTIVITY_CODE)
  end

  def can_view_detailed_health_records?
    activity_codes.include?(VIEW_DETAILED_HEALTH_RECORDS_ACTIVITY_CODE)
  end

  def can_view_shared_non_patient_identifiable_information?
    activity_codes.include?(
      VIEW_SHARED_NON_PATIENT_IDENTIFIABLE_INFORMATION_ACTIVITY_CODE
    )
  end

  def is_support?
    is_support_without_pii_access? || is_support_with_pii_access?
  end

  def is_support_without_pii_access?
    role_code == SUPPORT_ROLE &&
      can_view_shared_non_patient_identifiable_information?
  end

  def is_support_with_pii_access?
    role_code == SUPPORT_ROLE && can_view_detailed_health_records?
  end

  private

  def request_session_key = "cis2_info"
end
