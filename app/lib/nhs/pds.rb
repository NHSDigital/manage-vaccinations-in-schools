# frozen_string_literal: true

module NHS::PDS
  SEARCH_FIELDS = %w[
    _fuzzy-match
    _exact-match
    _history
    _max-results
    family
    given
    gender
    birthdate
    death-date
    email
    phone
    address-postalcode
    general-practitioner
  ].freeze

  class InvalidatedResource < StandardError
  end

  class InvalidNHSNumber < StandardError
  end

  class PatientNotFound < StandardError
  end

  class TooManyMatches < StandardError
  end

  class InvalidSearchData < StandardError
  end

  class << self
    def get_patient(nhs_number)
      return unless Flipper.enabled?(:pds)

      NHS::API.connection.get(
        "personal-demographics/FHIR/R4/Patient/#{nhs_number}"
      )
    rescue Faraday::BadRequestError => e
      if is_error?(e, "INVALID_RESOURCE_ID")
        raise InvalidNHSNumber, nhs_number
      else
        raise
      end
    rescue Faraday::ResourceNotFound => e
      if is_error?(e, "INVALIDATED_RESOURCE")
        raise InvalidatedResource, nhs_number
      elsif is_error?(e, "RESOURCE_NOT_FOUND")
        raise PatientNotFound, nhs_number
      else
        raise
      end
    end

    def search_patients(attributes)
      return unless Flipper.enabled?(:pds)

      if (missing_attrs = (attributes.keys.map(&:to_s) - SEARCH_FIELDS)).any?
        raise "Unrecognised attributes: #{missing_attrs.join(", ")}"
      end

      response =
        NHS::API.connection.get(
          "personal-demographics/FHIR/R4/Patient",
          attributes
        )

      if is_error?(response, "TOO_MANY_MATCHES")
        raise TooManyMatches
      else
        response
      end
    rescue Faraday::BadRequestError => e
      if is_error?(e, "INVALID_SEARCH_DATA")
        raise InvalidSearchData
      else
        raise
      end
    end

    private

    def is_error?(error_or_response, code)
      response =
        if error_or_response.is_a?(Faraday::ClientError)
          JSON.parse(error_or_response.response_body)
        elsif error_or_response.is_a?(Faraday::Response)
          error_or_response.body
        end

      return false if (issues = response["issue"]).blank?

      issues.any? do |issue|
        issue["details"]["coding"].any? { |coding| coding["code"] == code }
      end
    end
  end
end
