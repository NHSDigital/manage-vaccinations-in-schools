# frozen_string_literal: true

module MavisCLI
  module Teams
    class ResetNationalReporting < Dry::CLI::Command
      desc "Reset national reporting teams by removing all immunisation imports and associated data"

      option :workgroup,
             desc: "The workgroup of a specific team to reset (optional)"
      option :force,
             desc:
               "Ignore check if sync_national_reporting_to_imms_api feature is enabled"

      def call(workgroup: nil, force: false, **)
        MavisCLI.load_rails

        if !force && Flipper.enabled?(:sync_national_reporting_to_imms_api)
          puts "Error: This operation is not allowed while sync_national_reporting_to_imms_api is enabled."
          return
        end

        teams = find_teams(workgroup)

        if teams.empty?
          puts "No national reporting teams found."
          return
        end

        puts "Found #{teams.count} national reporting team(s) to reset:"
        teams.each do |team|
          puts "  - #{team.name} (#{team.workgroup})"
          puts "    - Cut-off date: #{team.national_reporting_cut_off_date}"
          puts "    - Immunisation imports (before cut-off): #{find_immunisation_imports_for_team(team).count}"
          puts "    - Total patients: #{find_patients_for_team(team).count}"

          vaccination_records = find_vaccination_records_for_team(team)
          puts "    - Vaccination records: #{vaccination_records.count}"
          if (synced = vaccination_records.synced_to_nhs_immunisations_api).any?
            puts "      - #{synced.count} vaccination record(s) have been" \
                   " synced to NHS Immunisations API and will NOT be deleted"
          end

          archive_reasons =
            find_archive_reasons_for_team(
              team,
              find_patients_for_team(team).ids
            )
          puts "    - Archive reasons: #{archive_reasons.count}"
        end
        puts

        unless MavisCLI.prompt_to_continue(
                 "This will permanently delete all data associated with the" \
                   "above teams. Continue? (y/n) "
               )
          puts "Operation cancelled."
          return
        end

        teams.each do |team|
          puts "Resetting #{team.name} (#{team.workgroup})..."
          reset_team(team)
        end

        puts "\nAll teams reset successfully."
      end

      private

      def find_teams(workgroup)
        if workgroup.present?
          team = Team.find_by(workgroup:)
          raise ArgumentError, "Team not found: #{workgroup}" if team.nil?

          unless team.has_national_reporting_access?
            raise ArgumentError,
                  "Team #{workgroup} is not a national reporting team"
          end
          if team.national_reporting_cut_off_date.nil?
            raise ArgumentError,
                  "Team #{workgroup} does not have a national reporting cut off date set; no data to delete"
          end

          [team]
        else
          Team
            .where(type: :national_reporting)
            .where.not(national_reporting_cut_off_date: nil)
        end
      end

      def reset_team(team)
        immunisation_imports = find_immunisation_imports_for_team(team)
        puts "  - Found #{immunisation_imports.count} immunisation import(s) created before team's cut off date: " \
               "#{team.national_reporting_cut_off_date}"

        patient_ids = find_patients_for_team(team).ids
        puts "  - Found #{patient_ids.count} patient(s) in this team"

        vaccination_records = find_vaccination_records_for_team(team)
        puts "  - Found #{vaccination_records.count} vaccination record(s) in this team's imports"

        not_synced_vaccination_records =
          vaccination_records.not_synced_to_nhs_immunisations_api
        synced_vaccination_records =
          vaccination_records.synced_to_nhs_immunisations_api
        patient_ids_of_not_synced_records =
          not_synced_vaccination_records.pluck(:patient_id).uniq
        if synced_vaccination_records.exists?
          puts "    - #{synced_vaccination_records.count} vaccination" \
                 " record(s) have been synced to NHS Immunisations API and" \
                 " will NOT be deleted"
          puts "    - #{not_synced_vaccination_records.count} vaccination" \
                 " record(s) will be deleted"
        end

        puts "Destroying vaccination records..."
        not_synced_vaccination_records.destroy_all

        puts "Refreshing immunisations imports..."
        if immunisation_imports.joins(:vaccination_records).any?
          immunisation_imports_with_records =
            immunisation_imports.joins(:vaccination_records).distinct
          immunisation_imports =
            immunisation_imports.where.not(
              id: immunisation_imports_with_records.select(:id)
            )
          puts " - #{immunisation_imports_with_records.count} immunisation" \
                 " import(s) have associated vaccination records and will NOT" \
                 " be deleted"
          puts " - #{immunisation_imports.count} immunisation import(s) will" \
                 " be deleted"
        end

        puts "Destroying immunisation imports..."
        immunisation_imports.destroy_all

        archive_reasons =
          ArchiveReason.where(
            patient_id: patient_ids_of_not_synced_records,
            team:
          )
        puts "Destroying #{archive_reasons.count} archive reasons..."
        archive_reasons.destroy_all

        puts "Updating patient-team relationships..."
        PatientTeamUpdater.call(
          patient_scope: Patient.where(id: patient_ids_of_not_synced_records)
        )

        patients_to_destroy =
          find_patients_without_team(patient_ids_of_not_synced_records)

        patient_ids_to_update =
          patient_ids_of_not_synced_records - patients_to_destroy.ids
        puts "  - Found #{patients_to_destroy.count}" \
               " patient(s) who were in the imports, and no longer have teams"

        puts "Destroying #{patients_to_destroy.count} patients..."
        PatientDeleter.call(
          patients: patients_to_destroy,
          confirm_production_delete: true
        )

        puts "Enqueueing jobs to update statuses for" \
               " #{patient_ids_to_update.size} patient(s) left over..."
        PatientStatusUpdaterJob.perform_bulk(patient_ids_to_update.zip)
      end

      def find_immunisation_imports_for_team(team)
        ImmunisationImport.where(team:).where(
          "immunisation_imports.created_at < ?",
          team.national_reporting_cut_off_date
        )
      end

      def find_patients_for_team(team)
        Patient.joins(:patient_teams).where(patient_teams: { team: }).distinct
      end

      def find_vaccination_records_for_team(team)
        VaccinationRecord.joins(:immunisation_imports).where(
          immunisation_imports: {
            id: find_immunisation_imports_for_team(team)
          }
        )
      end

      def find_archive_reasons_for_team(team, patient_ids)
        ArchiveReason.where(patient_id: patient_ids, team:)
      end

      def find_patients_without_team(patient_ids)
        Patient.where(id: patient_ids).where.missing(:patient_teams)
      end
    end
  end

  register "teams" do |prefix|
    prefix.register "reset-national-reporting", Teams::ResetNationalReporting
  end
end
