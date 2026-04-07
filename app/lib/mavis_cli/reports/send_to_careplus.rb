# frozen_string_literal: true

require "net/http"
require "cgi"

module MavisCLI
  module Reports
    class SendToCareplus < Dry::CLI::Command
      desc "Send a CarePlus CSV file to the CarePlus endpoint"

      example [
                "--input=tmp/automated_export.csv",
                "--input=/path/to/export.csv --endpoint=http://localhost:8080/MOCK/soap.SchImms.cls"
              ]

      TARGET_NAMESPACE =
        "https://careplus.syhapp.thirdparty.nhs.uk/MOCK/webservices"
      DEFAULT_BASE_URL = ENV.fetch("MOCK_CAREPLUS_URL", "http://localhost:8080")
      DEFAULT_ENDPOINT = "#{DEFAULT_BASE_URL}/MOCK/soap.SchImms.cls".freeze

      # TODO: retrieve credentials for given team
      SOAP_USERNAME = "mavis_user"
      SOAP_PASSWORD = "mavis_password"

      option :input, required: true, desc: "Path to the CSV file to send"
      option :endpoint,
             default: DEFAULT_ENDPOINT,
             desc: "SOAP endpoint URL (default: #{DEFAULT_ENDPOINT})"

      def call(input:, endpoint: DEFAULT_ENDPOINT, **)
        unless File.exist?(input)
          warn "File not found: '#{input}'"
          return
        end

        csv_payload = File.read(input)

        soap_body = build_soap_envelope(csv_payload)

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

      def build_soap_envelope(csv_payload)
        escaped_payload = CGI.escapeHTML(csv_payload)

        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope
              xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
              xmlns:car="#{TARGET_NAMESPACE}">
            <soap:Body>
              <car:InsertImmsRecord>
                <car:strUserId>#{SOAP_USERNAME}</car:strUserId>
                <car:strPwd>#{SOAP_PASSWORD}</car:strPwd>
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
