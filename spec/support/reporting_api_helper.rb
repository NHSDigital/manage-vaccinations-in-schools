# frozen_string_literal: true

module ReportingAPIHelper
  def valid_jwt_payload
    team = create(:team, :with_one_nurse)
    user = team.users.first
    {
      data: {
        user: user.as_json,
        cis2_info: {
          organisation_code: team.organisation.ods_code,
          workgroups: [team.workgroup],
          role_code: CIS2Info::NURSE_ROLES.first
        }
      }
    }
  end

  def valid_jwt
    JWT.encode(
      valid_jwt_payload,
      Settings.reporting_api.client_app.secret,
      "HS512"
    )
  end

  def invalid_jwt_payload
    { user: { id: -1 } }
  end

  def jwt_with_invalid_payload
    JWT.encode(
      invalid_jwt_payload,
      Settings.reporting_api.client_app.secret,
      "HS512"
    )
  end

  def refresh_reporting_views!
    PatientStatusUpdater.call
    ReportingAPI::Total.refresh!(concurrently: false)
  end
end
