# frozen_string_literal: true

namespace :ops_support do
  desc "Create an organisation and team for ops support users to access ops tools."
  task seed: :environment do
    organisation =
      Organisation.find_or_create_by!(ods_code: CIS2Info.support_organisation)

    Team.find_or_create_by!(
      organisation:,
      type: :support,
      name: "Operational Support Team",
      workgroup: CIS2Info::SUPPORT_WORKGROUP,
      days_before_consent_reminders: 0,
      days_before_consent_requests: 0,
      programmes: []
    )
  end
end
