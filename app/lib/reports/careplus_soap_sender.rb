# frozen_string_literal: true

require "net/http"
require "cgi"

class Reports::CareplusSoapSender
  TARGET_NAMESPACE_BASE = "https://careplus.syhapp.thirdparty.nhs.uk"
  SOAP_PATH = "/soap.SchImms.cls"

  class ServerError < StandardError
    attr_reader :response

    def initialize(response)
      @response = response
      super(
        "CarePlus SOAP request failed with HTTP #{response.code}: #{response.message}"
      )
    end
  end

  def initialize(csv_payload:, username:, password:, namespace:, endpoint: nil)
    @csv_payload = csv_payload
    @username = username
    @password = password
    @namespace = namespace
    @endpoint = endpoint || "http://localhost:8080/#{namespace}#{SOAP_PATH}"
  end

  def call
    uri = URI.parse(@endpoint)
    response = post_soap_request(uri, build_soap_envelope)
    raise ServerError, response unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def self.call(...) = new(...).call

  private_class_method :new

  private

  attr_reader :csv_payload, :username, :password, :namespace, :endpoint

  def build_soap_envelope
    escaped_payload = CGI.escapeHTML(csv_payload)
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
