# frozen_string_literal: true

module MavisCLI
  module Reports
    class ExportAutomatedCareplus < Dry::CLI::Command
      desc "Export a CarePlus CSV report using the automated exporter"

      example [
                "--ods_code=ABC123",
                "--ods_code=ABC123 --output=/tmp/export.csv",
                "--ods_code=ABC123 --workgroup=my_team --start_date=2025-09-01 --end_date=2026-03-10",
                "--ods_code=ABC123 --start_date=2025-09-01 --end_date=2026-03-10 --academic_year=2025"
              ]

      option :ods_code, required: true, desc: "ODS code of the organisation"
      option :workgroup,
             desc:
               "Team workgroup (required if the organisation has multiple teams)"
      option :academic_year,
             type: :integer,
             desc:
               "Academic year (e.g. 2025). Defaults to the current academic year"
      option :start_date,
             desc: "Start date in YYYY-MM-DD format. Defaults to today"
      option :end_date, desc: "End date in YYYY-MM-DD format. Defaults to today"
      option :output,
             default: "tmp/automated_export.csv",
             desc: "File path to write the CSV to"

      def call(
        ods_code:,
        start_date: nil,
        end_date: nil,
        workgroup: nil,
        academic_year: nil,
        output: "tmp/automated_export.csv",
        **
      )
        MavisCLI.load_rails

        organisation = Organisation.find_by(ods_code:)
        if organisation.nil?
          warn "Could not find organisation with ODS code '#{ods_code}'"
          return
        end

        teams = organisation.teams
        teams = teams.where(workgroup:) if workgroup

        if teams.empty?
          warn(
            if workgroup
              "Could not find team '#{workgroup}' for organisation '#{ods_code}'"
            else
              "Organisation '#{ods_code}' has no teams."
            end
          )
          return
        end

        if workgroup.nil? && teams.many?
          warn "Organisation '#{ods_code}' has multiple teams. Specify --workgroup."
          return
        end

        team = teams.sole

        unless team.careplus_enabled?
          warn "Team '#{team.name}' does not have CarePlus enabled."
          return
        end

        parsed_start_date =
          if start_date
            begin
              Date.parse(start_date)
            rescue ArgumentError
              warn "Invalid start_date '#{start_date}'. Expected YYYY-MM-DD format."
              return
            end
          else
            Time.zone.today
          end

        parsed_end_date =
          if end_date
            begin
              Date.parse(end_date)
            rescue ArgumentError
              warn "Invalid end_date '#{end_date}'. Expected YYYY-MM-DD format."
              return
            end
          else
            Time.zone.today
          end

        academic_year_value = academic_year&.to_i || AcademicYear.current

        records =
          ::Reports::AutomatedCareplusExporter.vaccination_records_scope(
            team:,
            academic_year: academic_year_value,
            start_date: parsed_start_date,
            end_date: parsed_end_date
          )

        csv =
          ::Reports::AutomatedCareplusExporter.from_records(
            team:,
            academic_year: academic_year_value,
            vaccination_records: records
          )

        now = Time.current

        # we'll create the export with status "sent" for now
        # in the future we'll change this to "pending" or
        # prevent this tool from creating database entries at all
        ActiveRecord::Base.transaction do
          careplus_export =
            CareplusExport.create!(
              team:,
              academic_year: academic_year_value,
              date_from: parsed_start_date,
              date_to: parsed_end_date,
              programme_types: team.programme_types,
              scheduled_at: now,
              sent_at: now,
              status: :sent,
              csv_filename: File.basename(output),
              csv_data: csv
            )

          if records.any?
            now_iso = now.iso8601(6)
            CareplusExportVaccinationRecord.insert_all!(
              records.map do |record|
                {
                  careplus_export_id: careplus_export.id,
                  vaccination_record_id: record.id,
                  change_type: 0,
                  created_at: now_iso,
                  updated_at: now_iso
                }
              end
            )
          end
        end

        File.write(output, csv)
        puts "Exported to #{output}"
      end
    end
  end

  register "reports" do |prefix|
    prefix.register "export-automated-careplus",
                    Reports::ExportAutomatedCareplus
  end
end
