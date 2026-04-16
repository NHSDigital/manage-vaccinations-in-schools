# frozen_string_literal: true

namespace :smoke do
  desc "Create a school and GP practice for smoke testing in production."
  task seed: :environment do
    Location.find_or_create_by!(
      name: "XXX Smoke Test School XXX",
      urn: "XXXXXX",
      type: "gias_school",
      address_line_1: "1 Test Street",
      address_town: "Test Town",
      address_postcode: "TE1 1ST",
      gias_establishment_number: 999_999,
      gias_local_authority_code: 999_999,
      gias_phase: "not_applicable",
      gias_year_groups: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    )

    Location.find_or_create_by!(
      name: "XXX Smoke Test GP XXX",
      ods_code: "Y90001", # https://digital.nhs.uk/developer/api-catalogue/personal-demographics-service-fhir/pds-fhir-api-test-data#production-smoke-testing
      type: "gp_practice"
    )
  end
end
