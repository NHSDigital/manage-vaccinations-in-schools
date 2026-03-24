# frozen_string_literal: true

module FHIRMapper
  class Location
    delegate :gias_school?, :clinic?, :type, :urn, :ods_code, to: :@location

    def initialize(location)
      @location = location
    end

    UNKNOWN_IDENTIFIER = "X99999"

    class UnknownValueError < StandardError
    end

    def fhir_reference
      if gias_school?
        value = urn || UNKNOWN_IDENTIFIER
        system = "https://fhir.hl7.org.uk/Id/urn-school-number"
      elsif clinic?
        value = ods_code || UNKNOWN_IDENTIFIER
        system = "https://fhir.nhs.uk/Id/ods-organization-code"
      else
        raise UnknownValueError, "Unsupported location type: #{type}"
      end

      FHIR::Reference.new(identifier: FHIR::Identifier.new(value:, system:))
    end
  end
end
