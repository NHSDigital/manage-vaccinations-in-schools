# frozen_string_literal: true

class PDSCascadingSearchJob < ApplicationJob
  include PDSThrottlingConcern

  queue_as :pds
  retry_on Faraday::ServerError, wait: :polynomially_longer

  def perform(searchable, step_name: nil, search_results: [], queue: :pds)
    step_name ||= :no_fuzzy_with_history

    SemanticLogger.tagged(
      searchable: "#{searchable.class.name}##{searchable.id}",
      step: step_name
    ) do
      result, pds_patient =
        search_for_patient(
          family_name: searchable.family_name,
          given_name: searchable.given_name,
          date_of_birth: searchable.date_of_birth,
          address_postcode: searchable.address_postcode,
          step_name: step_name
        )

      search_result = {
        step: step_name,
        result: result,
        nhs_number: pds_patient&.nhs_number,
        created_at: Time.current
      }.with_indifferent_access

      if searchable.is_a?(PatientChangeset)
        searchable.search_results << search_result
      end

      search_results << search_result

      searchable.save!

      next_step = steps[step_name][result]

      if result == :error || next_step.nil? || next_step == :give_up ||
           multiple_nhs_numbers_found?(search_results) ||
           next_step == :save_nhs_number_if_unique
        searchable.save!
        if searchable.is_a?(PatientChangeset)
          ProcessPatientChangesetJob.perform_later(searchable.id)
        else
          PatientUpdateFromPDSJob.perform_later(searchable, search_results)
        end
      elsif next_step.in?(steps.keys)
        raise "Recursive step detected: #{next_step}" if next_step == step_name
        enqueue_next_search(searchable, next_step, search_results, queue)
      else
        raise "Unknown step: #{next_step}"
      end
    end
  end

  private

  def search_for_patient(
    family_name:,
    given_name:,
    date_of_birth:,
    address_postcode:,
    step_name:
  )
    return :no_postcode, nil if address_postcode.blank?

    case step_name
    when :no_fuzzy_with_wildcard_given_name
      return :skip_step, nil if given_name.length <= 3
    when :no_fuzzy_with_wildcard_family_name
      return :skip_step, nil if family_name.length <= 3
    end

    query = {
      family_name: family_name.dup,
      given_name: given_name.dup,
      date_of_birth: date_of_birth.dup,
      address_postcode: address_postcode.dup,
      history: true,
      fuzzy: false
    }

    if steps[step_name][:format_query].respond_to?(:call)
      result = steps[step_name][:format_query].call(query)
      query = result if result.is_a?(Hash)
    end

    patient = PDS::Patient.search(**query)
    return :no_matches, nil if patient.nil?

    [:one_match, patient]
  rescue NHS::PDS::PatientNotFound
    [:no_matches, nil]
  rescue NHS::PDS::TooManyMatches
    [:too_many_matches, nil]
  rescue Faraday::TooManyRequestsError
    raise
  rescue NHS::PDS::InvalidSearchData,
         Faraday::ClientError,
         Faraday::ServerError => e
    Rails.logger.error("Error doing PDS search: #{e.message}")
    Sentry.capture_exception(e, level: "warning")
    [:error, nil]
  end

  def steps
    {
      no_fuzzy_with_history: {
        no_matches: :no_fuzzy_with_wildcard_postcode,
        one_match: :save_nhs_number_if_unique,
        too_many_matches: :no_fuzzy_without_history
      },
      no_fuzzy_without_history: {
        no_matches: :give_up,
        one_match: :save_nhs_number_if_unique,
        too_many_matches: :give_up,
        format_query: ->(query) { query.merge(history: false) }
      },
      no_fuzzy_with_wildcard_postcode: {
        no_matches: :no_fuzzy_with_wildcard_given_name,
        one_match: :no_fuzzy_with_wildcard_given_name,
        too_many_matches: :no_fuzzy_with_wildcard_given_name,
        format_query:
          lambda do |query|
            query[:address_postcode] = query[:address_postcode].dup
            query[:address_postcode][2..] = "*"
            query
          end
      },
      no_fuzzy_with_wildcard_given_name: {
        no_matches: :no_fuzzy_with_wildcard_family_name,
        one_match: :no_fuzzy_with_wildcard_family_name,
        too_many_matches: :no_fuzzy_with_wildcard_family_name,
        skip_step: :no_fuzzy_with_wildcard_family_name,
        format_query:
          lambda do |query|
            query[:given_name] = query[:given_name].dup
            query[:given_name][3..] = "*"
            query
          end
      },
      no_fuzzy_with_wildcard_family_name: {
        no_matches: :save_nhs_number_if_unique,
        one_match: :save_nhs_number_if_unique,
        too_many_matches: :save_nhs_number_if_unique,
        skip_step: :save_nhs_number_if_unique,
        format_query:
          lambda do |query|
            query[:family_name] = query[:family_name].dup
            query[:family_name][3..] = "*"
            query
          end
      }
    }
  end

  def enqueue_next_search(searchable, step_name, search_results, queue)
    searchable.save!

    PDSCascadingSearchJob.set(queue:).perform_later(
      searchable,
      step_name:,
      search_results:,
      queue:
    )
  end

  def unique_nhs_numbers(search_results)
    search_results.pluck("nhs_number").compact.uniq
  end

  def multiple_nhs_numbers_found?(search_results)
    unique_nhs_numbers(search_results).count > 1
  end
end
