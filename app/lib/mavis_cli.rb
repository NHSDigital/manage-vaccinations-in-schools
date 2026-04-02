# frozen_string_literal: true

module MavisCLI
  extend Dry::CLI::Registry

  def self.load_rails
    require_relative "../../config/environment"
  end

  def self.progress_bar(total)
    @progress_bar ||=
      ProgressBar.create(
        total:,
        format: "%a %b\u{15E7}%i %p%% %t",
        progress_mark: " ",
        remainder_mark: "\u{FF65}"
      )
  end

  def self.prompt_to_continue(message = "Continue? (y/n) ")
    print message

    response = $stdin.gets.chomp.downcase
    case response
    when /y(es)?/i
      true
    else
      false
    end
  end

  def self.terminal_lines
    `tput lines`.to_i
  end
end

require_relative "mavis_cli_helpers"
require_relative "mavis_cli/access_log"
require_relative "mavis_cli/clinics/add_to_team"
require_relative "mavis_cli/clinics/create"
require_relative "mavis_cli/generate/cohort_imports"
require_relative "mavis_cli/generate/consent_forms"
require_relative "mavis_cli/generate/consents"
require_relative "mavis_cli/generate/vaccination_records"
require_relative "mavis_cli/gias/check_import"
require_relative "mavis_cli/gias/download"
require_relative "mavis_cli/gias/import"
require_relative "mavis_cli/gp_practices/download"
require_relative "mavis_cli/gp_practices/import"
require_relative "mavis_cli/imports/recent"
require_relative "mavis_cli/local_authorities/download"
require_relative "mavis_cli/local_authorities/download_gias_codes"
require_relative "mavis_cli/local_authorities/download_postcode_mappings"
require_relative "mavis_cli/local_authorities/import"
require_relative "mavis_cli/local_authorities/import_gias_codes"
require_relative "mavis_cli/local_authorities/import_postcode_mappings"
require_relative "mavis_cli/nhs_api/access_token"
require_relative "mavis_cli/pds/get"
require_relative "mavis_cli/pds/search"
require_relative "mavis_cli/reports/export_automated_careplus"
require_relative "mavis_cli/schools/add_programme_year_group"
require_relative "mavis_cli/schools/add_to_team"
require_relative "mavis_cli/schools/create"
require_relative "mavis_cli/schools/create_site"
require_relative "mavis_cli/schools/move_patients"
require_relative "mavis_cli/schools/remove_from_team"
require_relative "mavis_cli/schools/remove_programme_year_group"
require_relative "mavis_cli/schools/show"
require_relative "mavis_cli/sessions/configure"
require_relative "mavis_cli/stats/consents_by_school"
require_relative "mavis_cli/stats/organisations"
require_relative "mavis_cli/stats/vaccinations"
require_relative "mavis_cli/stats/sessions"
require_relative "mavis_cli/subteams/create"
require_relative "mavis_cli/subteams/list"
require_relative "mavis_cli/teams/add_programme"
require_relative "mavis_cli/teams/list"
require_relative "mavis_cli/teams/merge"
require_relative "mavis_cli/teams/onboard"
require_relative "mavis_cli/teams/reset_national_reporting"
require_relative "mavis_cli/teams/set_national_reporting_cut_off_date"
require_relative "mavis_cli/users/create"
require_relative "mavis_cli/vaccination_records/bulk_edit"
require_relative "mavis_cli/vaccination_records/create_from_fhir"
require_relative "mavis_cli/vaccination_records/edit"
require_relative "mavis_cli/vaccination_records/generate_fhir"
require_relative "mavis_cli/vaccination_records/read_imms_api"
require_relative "mavis_cli/vaccination_records/search_imms_api"
require_relative "mavis_cli/vaccination_records/sync"
