# frozen_string_literal: true

require "net/http"
require "cgi"

module MavisCLI
  module Reports
    class SendToCareplus < Dry::CLI::Command
      desc "Send a CarePlus CSV file to the CarePlus endpoint"

      example [
                "--input=tmp/automated_export.csv",
                "--input=tmp/automated_export.csv --ods_code=ABC123",
                "--input=/path/to/export.csv --endpoint=http://localhost:8080/MOCK/soap.SchImms.cls"
              ]

      DEFAULT_BASE_URL = ENV.fetch("MOCK_CAREPLUS_URL", "http://localhost:8080")

      FALLBACK_NAMESPACE = "MOCK"
      FALLBACK_USERNAME = "mavis_user"
      FALLBACK_PASSWORD = "mavis_password"

      DEFAULT_ENDPOINT =
        "#{DEFAULT_BASE_URL}/#{FALLBACK_NAMESPACE}/soap.SchImms.cls".freeze

      option :input, required: true, desc: "Path to the CSV file to send"
      option :endpoint,
             desc:
               "SOAP endpoint URL (default: #{DEFAULT_BASE_URL}/<namespace>/soap.SchImms.cls)"
      option :ods_code,
             desc: "ODS code of the organisation (to use team credentials)"
      option :workgroup,
             desc:
               "Team workgroup (required if the organisation has multiple teams)"

      def call(input:, endpoint: nil, ods_code: nil, workgroup: nil, **)
        unless File.exist?(input)
          warn "File not found: '#{input}'"
          return
        end

        username, password, namespace =
          resolve_credentials(ods_code:, workgroup:)
        return if username.nil?

        endpoint ||= "#{DEFAULT_BASE_URL}/#{namespace}/soap.SchImms.cls"

        csv_payload = File.read(input)

        soap_body =
          build_soap_envelope(csv_payload, username:, password:, namespace:)

        uri = URI.parse(endpoint)
        response = post_soap_request(uri, soap_body)

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

        MavisCLI.load_rails

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

      def build_soap_envelope(csv_payload, username:, password:, namespace:)
        escaped_payload = CGI.escapeHTML(csv_payload)
        target_namespace =
          "https://careplus.syhapp.thirdparty.nhs.uk/#{namespace}/webservices"

        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope
              xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:car="#{target_namespace}">
            <soap:Body>
              <car:InsertImmsRecord>
                <car:strUserId>#{username}</car:strUserId>
                <car:strPwd>#{password}</car:strPwd>
                <car:strPayload>#{escaped_payload}</car:strPayload>
              </car:InsertImmsRecord>
            </soap:Body>
          </soap:Envelope>
        XML
      end

      def post_soap_request(uri, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "text/xml; charset=utf-8"
        request.body = body

        http.request(request)
      end
    end
  end

  register "reports" do |prefix|
    prefix.register "send-to-careplus", Reports::SendToCareplus
  end
end
