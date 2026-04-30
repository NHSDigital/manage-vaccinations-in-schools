# frozen_string_literal: true

# Enqueue jobs to search vaccination records in the NHS system for patients
# associated with upcoming sessions and for patients due for a rolling search.
#
# The approach is to perform daily searches for patients that have upcoming
# sessions, starting from 2 days before invitations or consent requests are sent
# out and ending once the last date of the sessions has passed. For all other
# patients we want to ensure a search is performed every 28 days at most.
class EnqueueVaccinationsSearchInNHSJob < ApplicationJob
  sidekiq_options queue: :immunisations_api_search

  def perform(programme_types = nil)
    programme_types ||= Programme.all.map(&:type)
    patient_ids = []

    if Flipper.enabled?(:imms_api_enqueue_session_searches)
      patient_ids += patient_ids_session_searches(programme_types:)
    end

    if Flipper.enabled?(:imms_api_enqueue_rolling_searches)
      patient_ids += patient_ids_for_rolling_searches
    end

    if patient_ids.any?
      SearchVaccinationRecordsInNHSJob.perform_bulk(patient_ids.uniq.zip)
    end
  end

  private

  def rolling_search_period_in_days = 28

  def patient_ids_session_searches(programme_types:)
    # stree-ignore
    Session
      .has_any_programme_types_of(programme_types)
      .scheduled
      .where("sessions.send_consent_requests_at <= ?", 2.days.from_now.to_date)
      .find_each
      .flat_map { |session| session.patients.with_nhs_number.ids }
  end

  # This implements a rolling search strategy for patients' vaccination records
  # in the NHS system. The goal is to ensure all patients have their vaccination
  # data refreshed within the defined period, while spreading the load evenly
  # over time.
  #
  # The batch size is calculated by dividing the total number of patients we can
  # search for (that have NHS numbers) by the rolling search period (in days).
  # This ensures that over the given search period all enrolled patients will
  # have a search performed.
  def patient_ids_for_rolling_searches
    patients_base =
      Patient.with_nhs_number.with_team_searchable_in_nhs_immunisations_api
    batch_size = (patients_base.count.to_f / rolling_search_period_in_days).ceil

    patients_with_recent_searches =
      PatientProgrammeVaccinationsSearch.where(
        "last_searched_at > ?",
        rolling_search_period_in_days.days.ago
      )

    patients_base
      .where.not(id: patients_with_recent_searches.select(:patient_id))
      .eager_load(:patient_programme_vaccinations_searches)
      .order(
        "patient_programme_vaccinations_searches.last_searched_at NULLS FIRST"
      )
      .limit(batch_size)
      .pluck(:id)
  end
end
