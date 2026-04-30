# frozen_string_literal: true

class EnqueueProcessUnmatchedConsentFormsJob < ApplicationJobSidekiq
  include SingleConcurrencyConcern

  sidekiq_options queue: :consents

  def perform
    ConsentForm.unmatched.find_each do |consent_form|
      ProcessConsentFormSidekiqJob.perform_async(consent_form.id)
    end
  end
end
