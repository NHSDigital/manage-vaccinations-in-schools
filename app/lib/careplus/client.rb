# frozen_string_literal: true

require "cgi"
require "net/http"
require "uri"

module Careplus
  class Client
    TARGET_NAMESPACE_BASE = "https://careplus.syhapp.thirdparty.nhs.uk"

    def initialize(username:, password:, namespace:, payload:)
      @username = username
      @password = password
      @namespace = namespace
      @payload = payload
    end

    def send_csv
      uri =
        URI.parse("#{Settings.careplus.base_url}/#{namespace}/soap.SchImms.cls")
      soap_body = build_soap_envelope
      post_soap_request(uri, soap_body)
    end

    def self.send_csv(...) = new(...).send_csv

    private_class_method :new

    private

    attr_reader :username, :password, :namespace, :payload

    def build_soap_envelope
      escaped_payload = CGI.escapeHTML(payload)
      target_namespace = "#{TARGET_NAMESPACE_BASE}/#{namespace}/webservices"

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
