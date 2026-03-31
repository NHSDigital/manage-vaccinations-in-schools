# frozen_string_literal: true

module FHIRMapper
  class VaccinationRecord
    delegate_missing_to :@vaccination_record

    MAVIS_SYSTEM_NAME =
      "http://manage-vaccinations-in-schools.nhs.uk/vaccination_records"
    MAVIS_NATIONAL_REPORTING_SYSTEM_NAME =
      "http://manage-vaccinations-in-schools.nhs.uk/national-reporting/vaccination-records"

    MILLILITER_SUB_STRINGS = %w[ml millilitre milliliter].freeze

    def initialize(vaccination_record)
      @vaccination_record = vaccination_record
    end

    def fhir_record
      immunisation = FHIR::Immunization.new(id: nhs_immunisations_api_id)

      if performed_by.present?
        immunisation.contained << FHIRMapper::User.new(
          performed_by
        ).fhir_practitioner(reference_id: "Practitioner1")
      end

      immunisation.contained << patient.fhir_record(reference_id: "Patient1")

      immunisation.extension = [fhir_vaccination_procedure_extension]
      immunisation.identifier = [fhir_identifier]

      immunisation.status = fhir_status
      immunisation.vaccineCode = vaccine.fhir_codeable_concept

      immunisation.patient = FHIR::Reference.new(reference: "#Patient1")
      immunisation.occurrenceDateTime = performed_at.to_time.iso8601(3)
      immunisation.recorded = created_at.iso8601(3)
      immunisation.primarySource =
        sourced_from_service? || sourced_from_national_reporting?
      immunisation.manufacturer = vaccine.fhir_manufacturer_reference

      immunisation.location = (location || ::Location.school.new).fhir_reference
      immunisation.lotNumber = batch_number
      immunisation.expirationDate = batch_expiry.to_s
      immunisation.site = fhir_site
      immunisation.route = fhir_route
      immunisation.doseQuantity = fhir_dose_quantity
      if performed_by.present?
        immunisation.performer << fhir_user_performer(
          reference_id: "Practitioner1"
        )
      end
      immunisation.performer << fhir_org_performer
      immunisation.reasonCode = [fhir_reason_code]
      immunisation.protocolApplied = [fhir_protocol_applied]

      immunisation
    end

    def self.from_fhir_record(fhir_record, patient:)
      attrs = {}
      notes = []

      attrs[:source] = "nhs_immunisations_api"

      attrs[:patient] = patient

      attrs[:nhs_immunisations_api_id] = fhir_record.id
      attrs[:nhs_immunisations_api_synced_at] = Time.current
      attrs[:nhs_immunisations_api_identifier_system] = fhir_record
        .identifier
        .sole
        .system
      attrs[:nhs_immunisations_api_identifier_value] = fhir_record
        .identifier
        .sole
        .value
      attrs[:nhs_immunisations_api_primary_source] = fhir_record.primarySource

      attrs[:programme] = Programme.from_fhir_record(fhir_record)

      attrs[:performed_at] = Time.zone.parse(fhir_record.occurrenceDateTime)
      attrs[:outcome] = outcome_from_fhir(fhir_record)

      location_system = fhir_record.location.identifier.system
      location_value = fhir_record.location.identifier.value
      unless location_value == "X99999"
        case location_system
        when "https://fhir.hl7.org.uk/Id/urn-school-number"
          attrs[:location] = ::Location.find_by(urn: location_value)
        when "https://fhir.nhs.uk/Id/ods-organization-code"
          attrs[:location] = ::Location.find_by(ods_code: location_value)
        end
      end

      if attrs[:location].nil?
        attrs[:location_name] = fhir_record.location.identifier.value
      end

      attrs[:performed_ods_code] = org_performer_ods_code_from_fhir(fhir_record)

      user_performer_name = user_performer_name_from_fhir(fhir_record)
      attrs[:performed_by_given_name] = user_performer_name&.given&.first
      attrs[:performed_by_family_name] = user_performer_name&.family

      attrs[:delivery_method] = delivery_method_from_fhir(fhir_record)
      attrs[:delivery_site] = site_from_fhir(fhir_record)

      dose_sequence = dose_sequence_from_fhir(fhir_record)
      if dose_sequence
        if dose_sequence > attrs[:programme].maximum_dose_sequence ||
             dose_sequence < 1
          notes << "Reported dose number: #{dose_sequence}"
        else
          attrs[:dose_sequence] = dose_sequence
        end
      else
        notes << dose_number_string_note_from_fhir(fhir_record)
      end

      attrs[:vaccine] = Vaccine.from_fhir_record(fhir_record)
      attrs[:batch_number] = fhir_record.lotNumber&.to_s
      attrs[:batch_expiry] = fhir_record.expirationDate&.to_date

      if attrs[:vaccine]
        attrs[:disease_types] = attrs[:vaccine].disease_types
        attrs[:full_dose] = full_dose_from_fhir(
          fhir_record,
          vaccine: attrs[:vaccine]
        )
      else
        attrs[:disease_types] = attrs[:programme].disease_types
        notes << vaccine_batch_notes_from_fhir(fhir_record)
        attrs[:full_dose] = true
      end

      attrs[:notes] = notes.compact.join("\n").presence

      ::VaccinationRecord.new(attrs)
    end

    private

    def fhir_identifier
      case source
      when "national_reporting"
        FHIR::Identifier.new(
          system: MAVIS_NATIONAL_REPORTING_SYSTEM_NAME,
          value: uuid
        )
      else
        FHIR::Identifier.new(system: MAVIS_SYSTEM_NAME, value: uuid)
      end
    end

    def fhir_vaccination_procedure_extension
      FHIR::Extension.new(
        url:
          "https://fhir.hl7.org.uk/StructureDefinition/Extension-UKCore-VaccinationProcedure",
        valueCodeableConcept: vaccine.fhir_procedure_coding(dose_sequence:)
      )
    end

    def fhir_status
      case outcome
      when "administered"
        "completed"
      when "refused", "unwell", "contraindicated", "already_had"
        "not-done"
      else
        raise ArgumentError, "Unknown outcome: #{outcome}"
      end
    end

    private_class_method def self.outcome_from_fhir(fhir_record)
      case fhir_record.status
      when "completed"
        "administered"
      when "not-done"
        raise "Cannot import not-done vaccination records"
      else
        raise "Unexpected vaccination status: \"#{fhir_record.status}\". Expected only 'completed' or 'not-done'"
      end
    end

    def fhir_site
      site_info =
        ::VaccinationRecord::DELIVERY_SITE_SNOMED_CODES_AND_TERMS[delivery_site]

      FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: "http://snomed.info/sct",
            code: site_info.first,
            display: site_info.last
          )
        ]
      )
    end

    private_class_method def self.site_from_fhir(fhir_record)
      site_code =
        fhir_record
          .site
          &.coding
          &.find { it.system == "http://snomed.info/sct" }
          &.code
      ::VaccinationRecord::DELIVERY_SITE_SNOMED_CODES_AND_TERMS
        .find { |_key, value| value.first == site_code }
        &.first
    end

    def fhir_route
      FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(
            system: "http://snomed.info/sct",
            code: delivery_method_snomed_code,
            display: delivery_method_snomed_term
          )
        ]
      )
    end

    private_class_method def self.delivery_method_from_fhir(fhir_record)
      route_code =
        fhir_record
          .route
          &.coding
          &.find { it.system == "http://snomed.info/sct" }
          &.code
      ::VaccinationRecord::DELIVERY_METHOD_SNOMED_CODES_AND_TERMS
        .find { |_key, value| value.first == route_code }
        &.first
    end

    def fhir_dose_quantity
      FHIR::Quantity.new(
        value: dose_volume_ml.to_f,
        unit: "ml",
        system: "http://snomed.info/sct",
        code: "258773002"
      )
    end

    private_class_method def self.dose_volume_ml_from_fhir(fhir_record)
      dq = fhir_record.doseQuantity

      return if dq.blank?

      if MILLILITER_SUB_STRINGS.any? { dq.unit.downcase.starts_with?(it) }
        dq.value.to_d
      end
    end

    private_class_method def self.full_dose_from_fhir(fhir_record, vaccine:)
      if vaccine.programme.flu? && vaccine.nasal?
        dose_volume_ml = dose_volume_ml_from_fhir(fhir_record)

        return nil if dose_volume_ml.nil?

        case dose_volume_ml.to_d
        when vaccine.dose_volume_ml
          true
        when vaccine.dose_volume_ml * 0.5.to_d
          false
        end
      else
        true
      end
    end

    private_class_method def self.vaccine_batch_notes_from_fhir(fhir_record)
      fhir_vaccine =
        fhir_record.vaccineCode&.coding&.find do
          it.system == "http://snomed.info/sct"
        end

      vaccine_snomed_code = fhir_vaccine&.code
      vaccine_description = fhir_vaccine&.display.presence

      [
        ("SNOMED product code: #{vaccine_snomed_code}" if vaccine_snomed_code),
        ("SNOMED description: #{vaccine_description}" if vaccine_description)
      ].compact.join("\n").presence
    end

    def fhir_user_performer(reference_id:)
      FHIR::Immunization::Performer.new(
        actor: FHIR::Reference.new(reference: "##{reference_id}")
      )
    end

    private_class_method def self.user_performer_name_from_fhir(fhir_record)
      performer_references =
        fhir_record
          .performer
          .reject { it.actor&.type == "Organization" }
          .map { it.actor.reference&.sub("#", "") }
          .compact
      user_actor =
        fhir_record.contained&.find do |c|
          c.id.in?(performer_references) && c.resourceType == "Practitioner"
        end
      user_actor&.name&.find { it&.use == "official" } ||
        user_actor&.name&.first
    end

    def fhir_org_performer
      FHIR::Immunization::Performer.new(
        actor: Organisation.fhir_reference(ods_code: performed_ods_code)
      )
    end

    private_class_method def self.org_performer_ods_code_from_fhir(fhir_record)
      org_actor =
        fhir_record.performer.find { it.actor&.type == "Organization" }&.actor
      org_actor&.identifier&.value
    end

    def fhir_reason_code
      FHIR::CodeableConcept.new(
        coding: [
          FHIR::Coding.new(code: "723620004", system: "http://snomed.info/sct")
        ]
      )
    end

    def fhir_protocol_applied
      FHIR::Immunization::ProtocolApplied.new(
        targetDisease: programme.fhir_target_disease_coding,
        doseNumberPositiveInt: dose_sequence,
        doseNumberString: dose_sequence.nil? ? "Unknown" : nil
      )
    end

    private_class_method def self.dose_sequence_from_fhir(fhir_record)
      protocol = fhir_record.protocolApplied&.sole

      if protocol&.doseNumberPositiveInt.present?
        return protocol&.doseNumberPositiveInt
      end

      Integer(protocol&.doseNumberString, exception: false)
    end

    private_class_method def self.dose_number_string_note_from_fhir(fhir_record)
      dose_string = fhir_record.protocolApplied&.sole&.doseNumberString

      return if dose_string.blank?

      "Reported dose number string: #{dose_string}"
    end
  end
end
