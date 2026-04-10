# frozen_string_literal: true

class SearchVaccinationRecordsInNHSJob < ImmunisationsAPIJob
  sidekiq_options queue: :immunisations_api_search

  ACADEMIC_YEAR_2025_CUTOFF_DATE = 2025.to_academic_year_date_range.first.freeze

  attr_reader :patient, :programmes

  def perform(patient_id)
    begin
      @patient = Patient.includes(teams: :organisation).find(patient_id)
    rescue ActiveRecord::RecordNotFound
      # This patient has since been merged with another so we don't need to
      # perform a search.
      return
    end

    @programmes = Programme.all_as_variants

    return unless feature_flags_enabled

    existing_vaccination_records.find_each do |vaccination_record|
      incoming_vaccination_record =
        incoming_vaccination_records.find do
          it.nhs_immunisations_api_id ==
            vaccination_record.nhs_immunisations_api_id
        end

      if incoming_vaccination_record
        vaccination_record.update!(
          incoming_vaccination_record
            .attributes
            .except("id", "uuid", "created_at")
            .merge(updated_at: Time.current)
        )

        incoming_vaccination_records.delete(incoming_vaccination_record)
      else
        vaccination_record.destroy!
      end
    end

    # Remaining incoming_vaccination_records are new.
    # Save non-discarded records first so they have IDs before discarded
    # duplicates reference them via duplicate_of_vaccination_record_id.
    incoming_vaccination_records.sort_by { it.discarded? ? 1 : 0 }.each(&:save!)

    update_vaccination_search_timestamps if patient.nhs_number.present?

    PatientStatusUpdater.call(patient:)

    incoming_vaccination_records.each do |vaccination_record|
      next if vaccination_record.discarded?

      AlreadyHadNotificationSender.call(vaccination_record:)
    end
  end

  private

  def select_programme_feature_flagged_records(vaccination_records)
    vaccination_records.select do
      Flipper.enabled?(:imms_api_search_job, it.programme)
    end
  end

  def reject_service_sourced_records(vaccination_records)
    vaccination_records.reject do |vaccination_record|
      [
        FHIRMapper::VaccinationRecord::MAVIS_SYSTEM_NAME,
        FHIRMapper::VaccinationRecord::MAVIS_NATIONAL_REPORTING_SYSTEM_NAME
      ].include?(vaccination_record.nhs_immunisations_api_identifier_system)
    end
  end

  def reject_pre_cutoff_records(vaccination_records)
    vaccination_records.reject do |vaccination_record|
      Flipper.enabled?(
        :imms_api_ignore_records_prior_to_2025_academic_year,
        vaccination_record.programme
      ) && vaccination_record.performed_at_date < ACADEMIC_YEAR_2025_CUTOFF_DATE
    end
  end

  def incoming_vaccination_records
    @incoming_vaccination_records ||=
      if patient.nhs_number.nil?
        []
      else
        fhir_bundle =
          NHS::ImmunisationsAPI.search_immunisations(patient, programmes:)

        extract_fhir_vaccination_records(fhir_bundle)
          .then { convert_to_vaccination_records(it) }
          .then { reject_service_sourced_records(it) }
          .then { deduplicate_vaccination_records(it) }
          .then { select_programme_feature_flagged_records(it) }
          .then { reject_pre_cutoff_records(it) }
      end
  end

  def existing_vaccination_records
    @existing_vaccination_records ||=
      patient
        .vaccination_records
        .includes(:identity_check)
        .sourced_from_nhs_immunisations_api
        .for_programmes(programmes)
  end

  def extract_fhir_vaccination_records(fhir_bundle)
    fhir_bundle
      .entry
      .map { it.resource if it.resource.resourceType == "Immunization" }
      .compact
  end

  def convert_to_vaccination_records(fhir_records)
    fhir_records.map do |fhir_record|
      FHIRMapper::VaccinationRecord.from_fhir_record(fhir_record, patient:)
    end
  end

  def deduplicate_vaccination_records(incoming_vaccination_records)
    service_vaccination_records =
      patient
        .vaccination_records
        .with_correct_source_for_nhs_immunisations_api
        .includes(:team)

    all_vaccination_records =
      incoming_vaccination_records + service_vaccination_records

    grouped_vaccination_records =
      all_vaccination_records.group_by do
        [it.performed_at_date, it.programme_type]
      end

    grouped_vaccination_records.each_value do |records|
      if records.any?(&:sourced_from_service?)
        # If there exists a Mavis record, set `discarded_at` for all incoming API records,
        # pointing each at the canonical Mavis record
        canonical = records.find(&:sourced_from_service?)
        records
          .select(&:sourced_from_nhs_immunisations_api?)
          .each do |record|
            record.discarded_at = Time.current
            record.duplicate_of_vaccination_record = canonical
          end
      elsif records.any?(&:nhs_immunisations_api_primary_source)
        # If some records have `primarySource: true`, set `discarded_at` for all `primarySource: false` records,
        # pointing each at the first `primarySource: true` record
        canonical = records.find(&:nhs_immunisations_api_primary_source)
        records
          .select(&:sourced_from_nhs_immunisations_api?)
          .reject(&:nhs_immunisations_api_primary_source)
          .each do |record|
            record.discarded_at = Time.current
            record.duplicate_of_vaccination_record = canonical
          end
      end
      # If no records are primary sources, keep all of them
    end

    incoming_vaccination_records
  end

  def update_vaccination_search_timestamps
    programmes.each do |programme|
      PatientProgrammeVaccinationsSearch
        .find_or_initialize_by(patient:, programme_type: programme.type)
        .tap { it.update!(last_searched_at: Time.current) }
    end
  end

  def feature_flags_enabled
    programmes.any? do |programme|
      Flipper.enabled?(:imms_api_search_job, programme)
    end
  end
end
