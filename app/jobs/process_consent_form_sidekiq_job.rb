# frozen_string_literal: true

class ProcessConsentFormSidekiqJob < ApplicationJobSidekiq
  include PDSThrottlingConcern

  sidekiq_options queue: :consents

  # We may enqueue this job more than once for the same ConsentForm during the parent
  # consent journey (e.g. once when the consent is recorded, and again after the optional
  # ethnicity flow is completed). Sidekiq does not guarantee ordering, so those jobs
  # could otherwise run concurrently and race each other while reading/updating the
  # same ConsentForm/Patient (and while calling out to PDS).
  #
  # Throttling concurrency to 1 per consent_form ID ensures only one job for a given
  # ConsentForm is processed at a time. This makes the job safe to re-run to pick up
  # newly submitted data like ethnicity.
  sidekiq_throttle(
    concurrency: {
      limit: 1,
      key_suffix: ->(consent_form_id) { consent_form_id }
    }
  )

  def perform(consent_form_id)
    ProcessConsentFormJob.new.perform(consent_form_id)
  end
end
