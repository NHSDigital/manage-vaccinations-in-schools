# frozen_string_literal: true

require_relative "../../careplus/client"

module MavisCLI
  module Reports
    class SendToCareplus < Dry::CLI::Command
      desc "Send a CarePlus CSV file to the CarePlus endpoint"

      example [
                "--input=tmp/automated_export.csv",
                "--input=tmp/automated_export.csv --ods_code=ABC123"
              ]

      FALLBACK_NAMESPACE = "MOCK"
      FALLBACK_USERNAME = "mavis_user"
      FALLBACK_PASSWORD = "mavis_password"

      option :input, required: true, desc: "Path to the CSV file to send"
      option :ods_code,
             desc: "ODS code of the organisation (to use team credentials)"
      option :workgroup,
             desc:
               "Team workgroup (required if the organisation has multiple teams)"

      def call(input:, ods_code: nil, workgroup: nil, **)
        MavisCLI.load_rails

        unless File.exist?(input)
          warn "File not found: '#{input}'"
          return
        end

        username, password, namespace =
          resolve_credentials(ods_code:, workgroup:)
        return if username.nil?

        csv_payload = File.read(input)

        response =
          Careplus::Client.send_csv(
            username:,
            password:,
            namespace:,
            payload: csv_payload
          )

        if response.is_a?(Net::HTTPSuccess)
          puts "Success (HTTP #{response.code})"
          puts response.body
        else
          warn "Request failed with HTTP #{response.code}: #{response.message}"
          warn response.body
        end
      end

      private

      def resolve_credentials(ods_code:, workgroup:)
        if ods_code.nil?
          return FALLBACK_USERNAME, FALLBACK_PASSWORD, FALLBACK_NAMESPACE
        end

        organisation = Organisation.find_by(ods_code:)
        if organisation.nil?
          warn "Could not find organisation with ODS code '#{ods_code}'"
          return nil, nil
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
          return nil, nil, nil
        end

        if workgroup.nil? && teams.many?
          warn "Organisation '#{ods_code}' has multiple teams. Specify --workgroup."
          return nil, nil, nil
        end

        team = teams.sole

        unless team.careplus_username.present? &&
                 team.careplus_password.present?
          warn "Team '#{team.name}' does not have CarePlus credentials configured."
          return nil, nil, nil
        end

        [
          team.careplus_username,
          team.careplus_password,
          team.careplus_namespace
        ]
      end
    end
  end

  register "reports" do |prefix|
    prefix.register "send-to-careplus", Reports::SendToCareplus
  end
end
